--[[
╔═══════════════════════════════════════════════════════════════╗
║  ConfigifyUI  —  Floating real-time config editor             ║
║  Place in: ReplicatedStorage.ConfigifyUI  (sibling of         ║
║            Configify)                                         ║
╚═══════════════════════════════════════════════════════════════╝

    DO NOT require this directly — call  cfg:buildUI()  instead.
]]

local ConfigifyUI = {}

-- ── Services ──────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ── Palette ───────────────────────────────────────────────────────────────────
local c2 = {
	BG         = Color3.fromRGB(13,  14,  18),
	SURFACE    = Color3.fromRGB(20,  22,  28),
	PANEL      = Color3.fromRGB(26,  28,  36),
	PANEL_NEST = Color3.fromRGB(22,  24,  32),   -- slightly different for nested rows
	SECTION_BG = Color3.fromRGB(18,  20,  26),
	BORDER     = Color3.fromRGB(45,  48,  62),
	ACCENT     = Color3.fromRGB(82,  183, 255),
	ACCENT2    = Color3.fromRGB(255, 107,  72),
	SUCCESS    = Color3.fromRGB(72,  255, 167),
	TEXT       = Color3.fromRGB(220, 225, 240),
	TEXT_DIM   = Color3.fromRGB(110, 118, 145),
	BOOL_ON    = Color3.fromRGB(72,  255, 167),
	BOOL_OFF   = Color3.fromRGB(255,  80,  80),
	NUMBER_BG  = Color3.fromRGB(17,  24,  36),
	STRING_BG  = Color3.fromRGB(20,  28,  20),
	NEST_INDENT= Color3.fromRGB(60,  100, 180),  -- indent bar colour for nested rows
}

local typeColors = {
	number  = Color3.fromRGB(100, 180, 255),
	boolean = Color3.fromRGB(255, 160,  80),
	string  = Color3.fromRGB(120, 230, 130),
	Vector2 = Color3.fromRGB(200, 130, 255),
	Vector3 = Color3.fromRGB(220, 110, 255),
	CFrame  = Color3.fromRGB(255, 200,  80),
	Color3  = Color3.fromRGB(255, 120, 180),
	UDim    = Color3.fromRGB(130, 220, 220),
	UDim2   = Color3.fromRGB( 80, 200, 200),
	table   = Color3.fromRGB( 90, 110, 150),
}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function newInst(class, props)
	local obj = Instance.new(class)
	for k, v in pairs(props) do obj[k] = v end
	return obj
end

local function corner(r, parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
	return c
end

local function stroke(thickness, color, parent)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function padding(t, r, b, l, parent)
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0, t)
	p.PaddingRight  = UDim.new(0, r)
	p.PaddingBottom = UDim.new(0, b)
	p.PaddingLeft   = UDim.new(0, l)
	p.Parent = parent
	return p
end

local function listLayout(parent, gap, fillDir)
	local l = Instance.new("UIListLayout")
	l.Padding       = UDim.new(0, gap or 0)
	l.FillDirection = fillDir or Enum.FillDirection.Vertical
	l.SortOrder     = Enum.SortOrder.LayoutOrder
	l.Parent        = parent
	return l
end

-- ── Drag ─────────────────────────────────────────────────────────────────────
local function makeDraggable(handle, frame)
	local dragging, dragStart, startPos
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = i.Position; startPos = frame.Position
		end
	end)
	handle.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

-- ── Section depth colour ──────────────────────────────────────────────────────
local depthColors = {
	Color3.fromRGB( 82, 183, 255),   -- depth 1: blue
	Color3.fromRGB(160, 120, 255),   -- depth 2: purple
	Color3.fromRGB( 72, 220, 180),   -- depth 3: teal
	Color3.fromRGB(255, 180,  80),   -- depth 4: amber
	Color3.fromRGB(255, 110, 160),   -- depth 5+: pink
}
local function depthColor(depth)
	return depthColors[math.min(depth, #depthColors)]
end

local function sectionDepth(section)
	if section == "" then return 0 end
	local n = 1
	for _ in section:gmatch("%.") do n = n + 1 end
	return n
end

-- ── Value row ─────────────────────────────────────────────────────────────────
-- key       : full dot-path  e.g. "Recoil.Vertical"
-- shortKey  : last segment   e.g. "Vertical"
-- indent    : pixel indent based on nesting depth
local function buildRow(cfg, key, valueType, scrollFrame, indent, refreshList)
	local rowH   = 42
	local isNested = indent > 0

	local row = newInst("Frame", {
		Name             = "row_" .. key,
		Size             = UDim2.new(1, 0, 0, rowH),
		BackgroundColor3 = isNested and c2.PANEL_NEST or c2.PANEL,
		BorderSizePixel  = 0,
		Parent           = scrollFrame,
	})
	corner(6, row)

	-- indent marker (coloured bar on left, width varies by depth)
	if indent > 0 then
		local depth = math.ceil(indent / 14)
		local barW  = 2 + depth
		local bar   = newInst("Frame", {
			Size             = UDim2.new(0, barW, 1, -10),
			Position         = UDim2.new(0, indent - barW - 2, 0, 5),
			BackgroundColor3 = depthColor(depth),
			BorderSizePixel  = 0,
			Parent           = row,
		})
		corner(2, bar)
	end

	-- type accent bar (far left)
	local accentBar = newInst("Frame", {
		Size             = UDim2.new(0, 3, 1, -10),
		Position         = UDim2.new(0, 0, 0, 5),
		BackgroundColor3 = typeColors[valueType] or c2.ACCENT,
		BorderSizePixel  = 0,
		Parent           = row,
	})
	corner(2, accentBar)

	-- short key label (last segment of dot-path)
	local segments   = key:split(".")
	local shortKey   = segments[#segments]
	local labelX    = indent + 10

	newInst("TextLabel", {
		Size             = UDim2.new(0, 155 - indent, 1, 0),
		Position         = UDim2.new(0, labelX, 0, 0),
		BackgroundTransparency = 1,
		Text             = shortKey,
		Font             = Enum.Font.GothamBold,
		TextSize         = 12,
		TextColor3       = c2.TEXT,
		TextXAlignment   = Enum.TextXAlignment.Left,
		TextTruncate     = Enum.TextTruncate.AtEnd,
		Parent           = row,
	})

	-- type badge
	local badge = newInst("TextLabel", {
		Size             = UDim2.new(0, 58, 0, 18),
		Position         = UDim2.new(0, 170, 0.5, -9),
		BackgroundColor3 = typeColors[valueType] or c2.ACCENT,
		BackgroundTransparency = 0.75,
		Text             = valueType,
		Font             = Enum.Font.GothamBold,
		TextSize         = 9,
		TextColor3       = typeColors[valueType] or c2.ACCENT,
		Parent           = row,
	})
	corner(4, badge)

	-- status dot
	local dot = newInst("Frame", {
		Size             = UDim2.new(0, 7, 0, 7),
		Position         = UDim2.new(1, -14, 0.5, -3),
		BackgroundColor3 = c2.TEXT_DIM,
		BorderSizePixel  = 0,
		Visible          = false,
		Parent           = row,
	})
	corner(99, dot)

	local function flashDot(ok)
		dot.BackgroundColor3 = ok and c2.SUCCESS or c2.ACCENT2
		dot.Visible = true
		task.delay(1.2, function() dot.Visible = false end)
	end

	-- ── Input widget ──────────────────────────────────────────────────────────
	local inputX = 234

	if valueType == "boolean" then
		local togBg = newInst("TextButton", {
			Size             = UDim2.new(0, 50, 0, 24),
			Position         = UDim2.new(0, inputX, 0.5, -12),
			BackgroundColor3 = cfg:get(key) and c2.BOOL_ON or c2.BOOL_OFF,
			BorderSizePixel  = 0,
			Text             = cfg:get(key) and "ON" or "OFF",
			Font             = Enum.Font.GothamBold,
			TextSize         = 11,
			TextColor3       = c2.BG,
			Parent           = row,
		})
		corner(6, togBg)
		togBg.MouseButton1Click:Connect(function()
			cfg:set(key, not cfg:get(key))
			local v = cfg:get(key)
			togBg.BackgroundColor3 = v and c2.BOOL_ON or c2.BOOL_OFF
			togBg.Text = v and "ON" or "OFF"
			flashDot(true)
		end)

	elseif valueType == "number" then
		local container = newInst("Frame", {
			Size             = UDim2.new(1, -(inputX + 20), 0, 28),
			Position         = UDim2.new(0, inputX, 0.5, -14),
			BackgroundTransparency = 1,
			Parent           = row,
		})
		listLayout(container, 2, Enum.FillDirection.Horizontal)

		local function mkBtn(txt)
			local b = newInst("TextButton", {
				Size             = UDim2.new(0, 26, 1, 0),
				BackgroundColor3 = c2.BORDER,
				BorderSizePixel  = 0,
				Text             = txt,
				Font             = Enum.Font.GothamBold,
				TextSize         = 14,
				TextColor3       = c2.TEXT,
				Parent           = container,
			})
			corner(5, b); return b
		end

		local decBtn = mkBtn("−")
		local box    = newInst("TextBox", {
			Size             = UDim2.new(1, -56, 1, 0),
			BackgroundColor3 = c2.NUMBER_BG,
			BorderSizePixel  = 0,
			Text             = cfg:toString(key),
			Font             = Enum.Font.Gotham,
			TextSize         = 12,
			TextColor3       = c2.TEXT,
			PlaceholderText  = "0",
			PlaceholderColor3= c2.TEXT_DIM,
			ClearTextOnFocus = false,
			Parent           = container,
		})
		corner(5, box); stroke(1, c2.BORDER, box)
		local incBtn = mkBtn("+")

		local function trySet(raw)
			local ok = cfg:setFromString(key, raw)
			flashDot(ok)
			if not ok then
				box.TextColor3 = c2.ACCENT2
				task.delay(0.8, function() box.TextColor3 = c2.TEXT end)
			end
			box.Text = cfg:toString(key)
		end
		box.FocusLost:Connect(function() trySet(box.Text) end)
		decBtn.MouseButton1Click:Connect(function()
			cfg:set(key, (tonumber(cfg:toString(key)) or 0) - 1)
			box.Text = cfg:toString(key); flashDot(true)
		end)
		incBtn.MouseButton1Click:Connect(function()
			cfg:set(key, (tonumber(cfg:toString(key)) or 0) + 1)
			box.Text = cfg:toString(key); flashDot(true)
		end)
		box.MouseWheelForward:Connect(function()
			cfg:set(key, (tonumber(cfg:toString(key)) or 0) + 1)
			box.Text = cfg:toString(key); flashDot(true)
		end)
		box.MouseWheelBackward:Connect(function()
			cfg:set(key, (tonumber(cfg:toString(key)) or 0) - 1)
			box.Text = cfg:toString(key); flashDot(true)
		end)

	elseif valueType == "Color3" then
		local container = newInst("Frame", {
			Size             = UDim2.new(1, -(inputX + 20), 0, 28),
			Position         = UDim2.new(0, inputX, 0.5, -14),
			BackgroundTransparency = 1,
			Parent           = row,
		})
		listLayout(container, 4, Enum.FillDirection.Horizontal)
		local swatch = newInst("Frame", {
			Size             = UDim2.new(0, 28, 1, 0),
			BackgroundColor3 = cfg:get(key),
			BorderSizePixel  = 0,
			Parent           = container,
		})
		corner(5, swatch); stroke(1, c2.BORDER, swatch)
		local colorBox = newInst("TextBox", {
			Size             = UDim2.new(1, -32, 1, 0),
			BackgroundColor3 = c2.NUMBER_BG,
			BorderSizePixel  = 0,
			Text             = cfg:toString(key),
			Font             = Enum.Font.Code,
			TextSize         = 11,
			TextColor3       = c2.TEXT,
			PlaceholderText  = "R, G, B",
			PlaceholderColor3= c2.TEXT_DIM,
			ClearTextOnFocus = false,
			Parent           = container,
		})
		corner(5, colorBox); stroke(1, c2.BORDER, colorBox)
		colorBox.FocusLost:Connect(function()
			local ok = cfg:setFromString(key, colorBox.Text)
			flashDot(ok)
			colorBox.Text = cfg:toString(key)
			swatch.BackgroundColor3 = cfg:get(key)
		end)

	else
		-- Generic: Vector2/3, CFrame, string, UDim, UDim2
		local box = newInst("TextBox", {
			Size             = UDim2.new(1, -(inputX + 20), 0, 28),
			Position         = UDim2.new(0, inputX, 0.5, -14),
			BackgroundColor3 = valueType == "string" and c2.STRING_BG or c2.NUMBER_BG,
			BorderSizePixel  = 0,
			Text             = cfg:toString(key),
			Font             = Enum.Font.Code,
			TextSize         = 11,
			TextColor3       = c2.TEXT,
			PlaceholderText  = valueType,
			PlaceholderColor3= c2.TEXT_DIM,
			ClearTextOnFocus = false,
			Parent           = row,
		})
		corner(5, box); stroke(1, c2.BORDER, box)
		box.FocusLost:Connect(function()
			local ok = cfg:setFromString(key, box.Text)
			flashDot(ok)
			if not ok then
				box.TextColor3 = c2.ACCENT2
				task.delay(0.8, function() box.TextColor3 = c2.TEXT end)
			end
			box.Text = cfg:toString(key)
		end)
	end

	return row
end

-- ── Section header ────────────────────────────────────────────────────────────
-- Returns { header frame, toggle function, childRows[] }
local function buildSectionHeader(section, scrollFrame, depth)
	local col     = depthColor(depth)
	local label   = section == "" and "⬡  root" or ("▸  " .. section)

	local header = newInst("TextButton", {
		Name             = "section_" .. section,
		Size             = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = c2.SECTION_BG,
		BorderSizePixel  = 0,
		Text             = "",
		Parent           = scrollFrame,
	})
	corner(6, header)
	stroke(1, Color3.new(col.R * 0.4, col.G * 0.4, col.B * 0.4), header)

	-- left colour tab
	local tab = newInst("Frame", {
		Size             = UDim2.new(0, 3, 1, -8),
		Position         = UDim2.new(0, 0, 0, 4),
		BackgroundColor3 = col,
		BorderSizePixel  = 0,
		Parent           = header,
	})
	corner(2, tab)

	-- indent dots to show depth
	local dotX = 10
	for i = 1, depth - 1 do
		newInst("Frame", {
			Size             = UDim2.new(0, 4, 0, 4),
			Position         = UDim2.new(0, dotX + (i-1) * 9, 0.5, -2),
			BackgroundColor3 = depthColor(i),
			BackgroundTransparency = 0.5,
			BorderSizePixel  = 0,
			Parent           = header,
		})
	end

	local textX = 10 + math.max(0, depth - 1) * 9 + 6
	newInst("TextLabel", {
		Size             = UDim2.new(1, -textX - 50, 1, 0),
		Position         = UDim2.new(0, textX, 0, 0),
		BackgroundTransparency = 1,
		Text             = section == "" and "root" or section,
		Font             = Enum.Font.GothamBold,
		TextSize         = 11,
		TextColor3       = col,
		TextXAlignment   = Enum.TextXAlignment.Left,
		Parent           = header,
	})

	local chevron = newInst("TextLabel", {
		Size             = UDim2.new(0, 20, 1, 0),
		Position         = UDim2.new(1, -28, 0, 0),
		BackgroundTransparency = 1,
		Text             = "▾",
		Font             = Enum.Font.GothamBold,
		TextSize         = 14,
		TextColor3       = col,
		Parent           = header,
	})

	local childRows = {}
	local collapsed = false

	header.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		chevron.Text = collapsed and "▸" or "▾"
		for _, r in ipairs(childRows) do
			r.Visible = not collapsed
		end
	end)

	return header, childRows
end

-- ── Main builder ──────────────────────────────────────────────────────────────
function ConfigifyUI.build(cfg, parent)
	parent = parent or PlayerGui

	local sg = newInst("ScreenGui", {
		Name             = "ConfigifyUI_" .. cfg._name,
		ResetOnSpawn     = false,
		ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset   = true,
		Parent           = parent,
	})

	-- ── Window ────────────────────────────────────────────────────────────────
	local winW, WIN_H = 570, 580
	local win = newInst("Frame", {
		Name             = "Window",
		Size             = UDim2.new(0, winW, 0, WIN_H),
		Position         = UDim2.new(0.5, -winW/2, 0.5, -WIN_H/2),
		BackgroundColor3 = c2.BG,
		BorderSizePixel  = 0,
		ClipsDescendants = true,
		Parent           = sg,
	})
	corner(10, win)
	stroke(1, c2.BORDER, win)

	local grad = Instance.new("UIGradient")
	grad.Color    = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 20, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 13, 17)),
	}
	grad.Rotation = 135
	grad.Parent   = win

	-- ── Title bar ─────────────────────────────────────────────────────────────
	local barH = 44
	local titleBar = newInst("Frame", {
		Size             = UDim2.new(1, 0, 0, barH),
		BackgroundColor3 = c2.SURFACE,
		BorderSizePixel  = 0,
		Parent           = win,
	})
	padding(0, 12, 0, 14, titleBar)

	newInst("Frame", {
		Size             = UDim2.new(0, 8, 0, 8),
		Position         = UDim2.new(0, 0, 0.5, -4),
		BackgroundColor3 = c2.ACCENT,
		BorderSizePixel  = 0,
		Parent           = titleBar,
	})
	newInst("TextLabel", {
		Size             = UDim2.new(0, 180, 1, 0),
		Position         = UDim2.new(0, 16, 0, 0),
		BackgroundTransparency = 1,
		Text             = "CONFIGIFY",
		Font             = Enum.Font.GothamBold,
		TextSize         = 11,
		TextColor3       = c2.ACCENT,
		TextXAlignment   = Enum.TextXAlignment.Left,
		Parent           = titleBar,
	})
	newInst("TextLabel", {
		Size             = UDim2.new(0, 160, 1, 0),
		Position         = UDim2.new(0, 110, 0, 0),
		BackgroundTransparency = 1,
		Text             = "— " .. cfg._name,
		Font             = Enum.Font.Gotham,
		TextSize         = 12,
		TextColor3       = c2.TEXT_DIM,
		TextXAlignment   = Enum.TextXAlignment.Left,
		Parent           = titleBar,
	})

	local resetBtn = newInst("TextButton", {
		Size             = UDim2.new(0, 66, 0, 26),
		Position         = UDim2.new(1, -130, 0.5, -13),
		BackgroundColor3 = c2.BORDER,
		BorderSizePixel  = 0,
		Text             = "↺  Reset",
		Font             = Enum.Font.GothamBold,
		TextSize         = 11,
		TextColor3       = c2.TEXT_DIM,
		Parent           = titleBar,
	})
	corner(6, resetBtn)

	local minBtn = newInst("TextButton", {
		Size             = UDim2.new(0, 30, 0, 26),
		Position         = UDim2.new(1, -90, 0.5, -13),
		BackgroundColor3 = Color3.fromRGB(40, 40, 20),
		BorderSizePixel  = 0,
		Text             = "—",
		Font             = Enum.Font.GothamBold,
		TextSize         = 13,
		TextColor3       = Color3.fromRGB(255, 210, 60),
		Parent           = titleBar,
	})
	corner(6, minBtn)

	local closeBtn = newInst("TextButton", {
		Size             = UDim2.new(0, 30, 0, 26),
		Position         = UDim2.new(1, -56, 0.5, -13),
		BackgroundColor3 = Color3.fromRGB(60, 25, 25),
		BorderSizePixel  = 0,
		Text             = "✕",
		Font             = Enum.Font.GothamBold,
		TextSize         = 13,
		TextColor3       = Color3.fromRGB(255, 90, 90),
		Parent           = titleBar,
	})
	corner(6, closeBtn)

	makeDraggable(titleBar, win)

	-- ── Search bar ────────────────────────────────────────────────────────────
	local searchFrame = newInst("Frame", {
		Size             = UDim2.new(1, -24, 0, 32),
		Position         = UDim2.new(0, 12, 0, barH + 8),
		BackgroundColor3 = c2.SURFACE,
		BorderSizePixel  = 0,
		Parent           = win,
	})
	corner(7, searchFrame)
	stroke(1, c2.BORDER, searchFrame)
	padding(0, 10, 0, 32, searchFrame)

	newInst("TextLabel", {
		Size             = UDim2.new(0, 18, 1, 0),
		Position         = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1,
		Text             = "⌕",
		Font             = Enum.Font.GothamBold,
		TextSize         = 16,
		TextColor3       = c2.TEXT_DIM,
		Parent           = searchFrame,
	})

	local searchBox = newInst("TextBox", {
		Size             = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text             = "",
		PlaceholderText  = "Search by key path…  e.g. Recoil.Vertical",
		Font             = Enum.Font.Code,
		TextSize         = 11,
		TextColor3       = c2.TEXT,
		PlaceholderColor3= c2.TEXT_DIM,
		ClearTextOnFocus = false,
		Parent           = searchFrame,
	})

	-- ── Stats bar ─────────────────────────────────────────────────────────────
	local statsY = barH + 8 + 32 + 6
	local statsBar = newInst("Frame", {
		Size             = UDim2.new(1, -24, 0, 22),
		Position         = UDim2.new(0, 12, 0, statsY),
		BackgroundTransparency = 1,
		Parent           = win,
	})
	listLayout(statsBar, 6, Enum.FillDirection.Horizontal)

	local function statChip(txt, col)
		local chip = newInst("Frame", {
			Size             = UDim2.new(0, 0, 1, 0),
			AutomaticSize    = Enum.AutomaticSize.X,
			BackgroundColor3 = col,
			BackgroundTransparency = 0.82,
			Parent           = statsBar,
		})
		corner(4, chip); padding(0, 8, 0, 8, chip)
		newInst("TextLabel", {
			Size             = UDim2.new(0, 0, 1, 0),
			AutomaticSize    = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text             = txt,
			Font             = Enum.Font.GothamBold,
			TextSize         = 10,
			TextColor3       = col,
			Parent           = chip,
		})
	end

	local fieldCount = 0
	local sectionCount = 0
	cfg:forEach(function() fieldCount += 1 end)
	for _, s in ipairs(cfg:sections()) do
		if s ~= "" then sectionCount += 1 end
	end

	statChip(fieldCount .. " fields", c2.ACCENT)
	statChip(sectionCount .. " groups", Color3.fromRGB(160, 120, 255))
	statChip(cfg._name, c2.TEXT_DIM)

	-- ── Scroll frame ──────────────────────────────────────────────────────────
	local scrollY = statsY + 22 + 6
	local footerH = 36
	local scroll = newInst("ScrollingFrame", {
		Size             = UDim2.new(1, -24, 0, WIN_H - scrollY - footerH - 16),
		Position         = UDim2.new(0, 12, 0, scrollY),
		BackgroundTransparency = 1,
		BorderSizePixel  = 0,
		ScrollBarThickness   = 3,
		ScrollBarImageColor3 = c2.ACCENT,
		CanvasSize           = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize  = Enum.AutomaticSize.Y,
		Parent           = win,
	})
	listLayout(scroll, 3)
	padding(0, 0, 4, 0, scroll)

	-- ── Footer ────────────────────────────────────────────────────────────────
	local footer = newInst("Frame", {
		Size             = UDim2.new(1, 0, 0, footerH),
		Position         = UDim2.new(0, 0, 1, -footerH),
		BackgroundColor3 = c2.SURFACE,
		BorderSizePixel  = 0,
		Parent           = win,
	})
	padding(0, 12, 0, 12, footer)
	newInst("TextLabel", {
		Size             = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text             = "Changes written live  •  dot-paths: Recoil.Vertical  •  Configify",
		Font             = Enum.Font.Gotham,
		TextSize         = 10,
		TextColor3       = c2.TEXT_DIM,
		TextXAlignment   = Enum.TextXAlignment.Center,
		Parent           = footer,
	})

	-- ── Populate rows grouped by section ─────────────────────────────────────
	-- Build a map: section → list of { key, valueType }
	local sectionFields = {}   -- ordered list of section strings
	local sectionMap    = {}   -- section → { {key, valueType} }
	local seenSections  = {}

	cfg:forEach(function(key, valueType, _, section)
		if not seenSections[section] then
			seenSections[section] = true
			sectionFields[#sectionFields + 1] = section
			sectionMap[section] = {}
		end
		sectionMap[section][#sectionMap[section] + 1] = { key = key, valueType = valueType }
	end)

	-- allRows: key → { row frame, sectionChildList }
	-- sectionHeaders: section → header frame
	local allRows        = {}   -- key → row Frame
	local sectionHeaders = {}   -- section → header Frame
	local sectionChildLists = {} -- section → childRows[]

	for _, section in ipairs(sectionFields) do
		local depth = sectionDepth(section)
		local indent = depth * 14

		-- section header (skip for root section "")
		local childRows
		if section ~= "" then
			local header
			header, childRows = buildSectionHeader(section, scroll, depth)
			sectionHeaders[section] = header
			sectionChildLists[section] = childRows
		else
			childRows = nil   -- root rows don't belong to a collapsible group
		end

		for _, field in ipairs(sectionMap[section]) do
			local row = buildRow(cfg, field.key, field.valueType, scroll, indent)
			allRows[field.key] = row
			if childRows then
				childRows[#childRows + 1] = row
			end
		end
	end

	-- ── Search filter ─────────────────────────────────────────────────────────
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = searchBox.Text:lower()
		if q == "" then
			-- restore all rows and headers to their natural visibility
			for _, row in pairs(allRows) do row.Visible = true end
			for section, hdr in pairs(sectionHeaders) do
				hdr.Visible = true
				-- re-apply whatever collapsed state the header has
				local childRows = sectionChildLists[section]
				-- (chevron state is internal — just make sure header is shown)
			end
		else
			-- hide/show rows by match, hide section headers that have no visible children
			local sectionHasMatch = {}
			for key, row in pairs(allRows) do
				local match = key:lower():find(q, 1, true) ~= nil
				row.Visible = match
				if match then
					-- mark all ancestor sections as having a match
					local parts = key:split(".")
					for i = 1, #parts - 1 do
						local s = table.concat(parts, ".", 1, i)
						sectionHasMatch[s] = true
					end
				end
			end
			for section, hdr in pairs(sectionHeaders) do
				hdr.Visible = sectionHasMatch[section] == true
			end
		end
	end)

	-- ── Close / Minimize ──────────────────────────────────────────────────────
	closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

	local minimised = false
	minBtn.MouseButton1Click:Connect(function()
		minimised = not minimised
		scroll.Visible      = not minimised
		searchFrame.Visible = not minimised
		statsBar.Visible    = not minimised
		footer.Visible      = not minimised
		win.Size = minimised
			and UDim2.new(0, winW, 0, barH)
			or  UDim2.new(0, winW, 0, WIN_H)
	end)

	-- ── Reset ─────────────────────────────────────────────────────────────────
	resetBtn.MouseButton1Click:Connect(function()
		cfg:reset()
		for key, row in pairs(allRows) do
			-- refresh text boxes
			local box = row:FindFirstChildWhichIsA("TextBox", true)
			if box then box.Text = cfg:toString(key) end
			-- refresh boolean toggles
			local tog = row:FindFirstChildWhichIsA("TextButton", true)
			if tog then
				local v = cfg:get(key)
				if typeof(v) == "boolean" then
					tog.BackgroundColor3 = v and c2.BOOL_ON or c2.BOOL_OFF
					tog.Text = v and "ON" or "OFF"
				end
			end
			-- refresh Color3 swatches
			local swatch = row:FindFirstChild("Frame", true)
			if swatch and cfg:get(key) and typeof(cfg:get(key)) == "Color3" then
				-- the swatch is the first Frame child of the container
				local container = row:FindFirstChildWhichIsA("Frame", true)
				if container then
					for _, child in ipairs(container:GetChildren()) do
						if child:IsA("Frame") then
							child.BackgroundColor3 = cfg:get(key)
						end
					end
				end
			end
		end
	end)

	return sg
end

return ConfigifyUI