if _G.MagmaMM2Cleanup then
	pcall(_G.MagmaMM2Cleanup)
	task.wait(0.5)
end

-- Shut down the old F$VL (WindUI) script if it is still running or in autoexec, so only Magma is on screen.
pcall(function()
	if _G.FVLV2Cleanup then
		_G.__FVLReloading = true
		pcall(_G.FVLV2Cleanup)
		_G.__FVLReloading = nil
	end

	if _G.FVLV2 and _G.FVLV2.Destroy then
		pcall(function()
			_G.FVLV2:Destroy()
		end)
	end

	_G.FVLV2, _G.FVLV2Cleanup = nil, nil

	for _, container in ipairs({ (type(gethui) == "function" and gethui()) or false, game:GetService("CoreGui") }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child.Name == "WindUI" or child.Name:match("^WindUI/") or child.Name == "FVLESP" or child.Name == "FVLCard" then
					child:Destroy()
				end
			end
		end
	end
end)

local Magma = (function()
local userInputService = game:GetService("UserInputService")
local textService = game:GetService("TextService")
local tweenService = game:GetService("TweenService")
local workspaceService = game:GetService("Workspace")
local playersService = game:GetService("Players")
local httpService = game:GetService("HttpService")

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local SIDEBAR_W = 104
local MAX_LIST_ROWS = 6
local CONFIG_DIR = "MagmaMM2/configs"

local THEME = {
	background = Color3.fromRGB(13, 13, 15),
	panel = Color3.fromRGB(19, 19, 22),
	control = Color3.fromRGB(26, 26, 30),
	line = Color3.fromRGB(36, 36, 41),
	accent = Color3.fromRGB(200, 48, 68),
	accentDark = Color3.fromRGB(96, 30, 40),
	accentLight = Color3.fromRGB(235, 80, 100),
	text = Color3.fromRGB(150, 150, 156),
	textBright = Color3.fromRGB(225, 225, 228),
}

local ICON_BARS = {
	plus = { { 0.5, 0.5, 0.8, 0.18, 0 }, { 0.5, 0.5, 0.18, 0.8, 0 } },
	chevron = { { 0.3, 0.5, 0.55, 0.16, 40 }, { 0.7, 0.5, 0.55, 0.16, -40 } },
}

local function make(class, props)
	local instance = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil

	for key, value in next, props do
		instance[key] = value
	end

	instance.Parent = parent
	return instance
end

local function textLabel(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextSize = props.TextSize or 11
	props.TextColor3 = props.TextColor3 or THEME.text
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props)
end

local function addStroke(parent, color)
	return make("UIStroke", {
		Color = color or THEME.line,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function round(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function tweenTo(instance, duration, goal, style, direction)
	tweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal):Play()
end

local function makeIcon(parent, name, color, size, position)
	local holder = make("Frame", {
		Position = position or UDim2.new(),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = parent,
	})

	for _, bar in next, ICON_BARS[name] or ICON_BARS.plus do
		local frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(bar[1], bar[2]),
			Size = UDim2.fromScale(bar[3], bar[4]),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = bar[5],
			Parent = holder,
		})
		round(frame, 1)
	end

	return holder
end

local function escapeRich(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local Magma = {}

function Magma.new(subtitle)
	local guiParent = (type(gethui) == "function" and gethui()) or playersService.LocalPlayer:WaitForChild("PlayerGui")
	local camera = workspaceService.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(800, 400)
	local windowWidth = math.min(560, viewport.X - 40)
	local windowHeight = math.min(330, viewport.Y - 40)

	local ui = { notificationsEnabled = true, flags = {} }
	local connections = {}
	local binds = {}
	local destroyCallbacks = {}
	local activeDrag = nil
	local activeEnd = nil
	local listeningBind = nil
	local openPopup = nil
	local tooltipToken = 0
	local menuKey = Enum.KeyCode.G
	local menuLocked = false
	local tabs = {}

	for _, old in ipairs(guiParent:GetChildren()) do
		if old.Name == "MagmaGui" then
			old:Destroy()
		end
	end

	local gui = make("ScreenGui", {
		Name = "MagmaGui",
		ResetOnSpawn = false,
		DisplayOrder = 1000000,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = guiParent,
	})

	local blur = nil

	pcall(function()
		local lighting = game:GetService("Lighting")
		local old = lighting:FindFirstChild("MagmaBlur")

		if old then
			old:Destroy()
		end

		blur = Instance.new("BlurEffect")
		blur.Name = "MagmaBlur"
		blur.Size = 0
		blur.Parent = lighting
	end)

	local dim = make("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 0,
		Parent = gui,
	})

	local root = make("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(windowWidth, windowHeight),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	local shadow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 36, 1, 36),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = root,
	})

	round(shadow, 28)

	local window = make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 1,
		Parent = root,
	})

	round(window, 16)

	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(26, 17, 22), Color3.fromRGB(11, 11, 14)),
		Rotation = 90,
		Parent = window,
	})

	local windowStroke = addStroke(window, THEME.accent)
	windowStroke.Thickness = 1.5

	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, THEME.accent),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 24, 32)),
			ColorSequenceKeypoint.new(1, THEME.accent),
		}),
		Rotation = 45,
		Parent = windowStroke,
	})

	local windowScale = make("UIScale", { Scale = 1, Parent = window })

	local header = make("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Active = true,
		Parent = window,
	})

	local logoWidth = textService:GetTextSize("magma", 17, FONT_BOLD, Vector2.new(400, 40)).X

	textLabel({
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.fromOffset(logoWidth + 6, 38),
		Text = '<font color="rgb(235,235,238)">mag</font><font color="rgb(220,60,80)">ma</font>',
		RichText = true,
		Font = FONT_BOLD,
		TextSize = 17,
		Parent = header,
	})

	if subtitle then
		local chipWidth = textService:GetTextSize(string.upper(subtitle), 9, FONT_BOLD, Vector2.new(400, 40)).X + 16

		local chip = make("Frame", {
			Position = UDim2.fromOffset(16 + logoWidth + 12, 10),
			Size = UDim2.fromOffset(chipWidth, 18),
			BackgroundColor3 = THEME.accent,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Parent = header,
		})

		round(chip, 9)
		addStroke(chip, THEME.accentDark)

		textLabel({
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(subtitle),
			TextColor3 = THEME.accentLight,
			Font = FONT_BOLD,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = chip,
		})
	end

	local headerLine = make("Frame", {
		Position = UDim2.new(0, 14, 1, -1),
		Size = UDim2.new(1, -28, 0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = header,
	})

	local headerGradient = make("UIGradient", {
		Color = ColorSequence.new(THEME.accent, THEME.accent),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.15),
			NumberSequenceKeypoint.new(0.65, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-0.35, 0),
		Parent = headerLine,
	})

	tweenService:Create(headerGradient, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.35, 0) }):Play()

	make("Frame", {
		Position = UDim2.fromOffset(SIDEBAR_W, 46),
		Size = UDim2.new(0, 1, 1, -58),
		BackgroundColor3 = THEME.line,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = window,
	})

	local sidebar = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(0, SIDEBAR_W, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window,
	})

	make("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebar,
	})

	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = sidebar })

	local popupLayer = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = window,
	})

	local catcher = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 51,
		Parent = popupLayer,
	})

	local popupClosers = {}

	local function closePopup()
		if openPopup then
			openPopup:Destroy()
			openPopup = nil
		end

		for _, closer in next, popupClosers do
			pcall(closer)
		end

		table.clear(popupClosers)
		catcher.Visible = false
	end

	table.insert(connections, catcher.Activated:Connect(closePopup))

	local function beginPopup(anchor, width, height, onClose)
		closePopup()
		catcher.Visible = true

		if onClose then
			table.insert(popupClosers, onClose)
		end

		local base = popupLayer.AbsolutePosition
		local position = anchor.AbsolutePosition - base
		local y = position.Y + anchor.AbsoluteSize.Y + 3

		if y + height > windowHeight - 4 then
			y = math.max(position.Y - height - 3, 4)
		end

		local popup = make("Frame", {
			Position = UDim2.fromOffset(math.min(position.X, windowWidth - width - 4), y),
			Size = UDim2.fromOffset(width, 0),
			BackgroundColor3 = Color3.fromRGB(20, 20, 25),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 52,
			Parent = popupLayer,
		})

		addStroke(popup, THEME.accentDark)
		round(popup, 9)
		tweenTo(popup, 0.14, { Size = UDim2.fromOffset(width, height) })
		openPopup = popup

		return popup
	end

	local function showTooltip(anchor, text)
		tooltipToken += 1

		local token = tooltipToken
		local base = popupLayer.AbsolutePosition
		local position = anchor.AbsolutePosition - base
		local size = textService:GetTextSize(text, 10, FONT, Vector2.new(180, 200))

		local tip = make("Frame", {
			Position = UDim2.fromOffset(math.min(position.X + 10, windowWidth - size.X - 20), position.Y + 14),
			Size = UDim2.fromOffset(size.X + 12, size.Y + 10),
			BackgroundColor3 = Color3.fromRGB(26, 26, 32),
			BorderSizePixel = 0,
			ZIndex = 60,
			Parent = popupLayer,
		})

		addStroke(tip, THEME.accentDark)
		round(tip, 8)

		textLabel({
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.new(1, -12, 1, -10),
			Text = text,
			TextSize = 10,
			TextWrapped = true,
			TextColor3 = THEME.textBright,
			ZIndex = 61,
			Parent = tip,
		})

		task.delay(2.5, function()
			if tooltipToken == token then
				tip:Destroy()
			end
		end)
	end

	table.insert(connections, userInputService.InputChanged:Connect(function(input)
		if activeDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			activeDrag(input)
		end
	end))

	table.insert(connections, userInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			activeDrag = nil

			if activeEnd then
				local finish = activeEnd
				activeEnd = nil
				finish()
			end
		end
	end))

	table.insert(connections, header.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end

		local start = input.Position
		local origin = root.Position

		activeDrag = function(moved)
			local delta = moved.Position - start
			root.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
		end
	end))

	local function hoverEffect(button, onEnter, onLeave)
		table.insert(connections, button.MouseEnter:Connect(onEnter))
		table.insert(connections, button.MouseLeave:Connect(onLeave))
	end

	local function pressEffect(button, scale)
		table.insert(connections, button.InputBegan:Connect(function(input)
			if isPress(input) then
				tweenTo(scale, 0.08, { Scale = 0.96 })
			end
		end))

		table.insert(connections, button.InputEnded:Connect(function(input)
			if isPress(input) then
				tweenTo(scale, 0.12, { Scale = 1 })
			end
		end))
	end

	local function registerFlag(flag, getter, setter)
		if flag then
			ui.flags[flag] = { get = getter, set = setter }
		end
	end

	local function addTooltipMark()
		return
	end

	local function openColorPicker(anchor, current, onChange)
		local popup = beginPopup(anchor, 148, 124)
		local hue, saturation, value = current:ToHSV()

		local square = make("Frame", {
			Position = UDim2.fromOffset(7, 7),
			Size = UDim2.fromOffset(134, 88),
			BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 53,
			Parent = popup,
		})

		round(square, 6)

		local white = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 54,
			Parent = square,
		})

		round(white, 6)
		make("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })

		local black = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 55,
			Parent = square,
		})

		round(black, 6)
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })

		local marker = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(9, 9),
			BackgroundTransparency = 1,
			ZIndex = 57,
			Parent = square,
		})

		round(marker, 999)
		make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = marker })

		local bar = make("Frame", {
			Position = UDim2.fromOffset(7, 103),
			Size = UDim2.fromOffset(134, 10),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 53,
			Parent = popup,
		})

		round(bar, 5)

		local keypoints = {}

		for index = 0, 6 do
			table.insert(keypoints, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1)))
		end

		make("UIGradient", { Color = ColorSequence.new(keypoints), Parent = bar })

		local hueMarker = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(5, 14),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 56,
			Parent = bar,
		})

		round(hueMarker, 3)

		local function refresh()
			square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			marker.Position = UDim2.fromScale(saturation, 1 - value)
			hueMarker.Position = UDim2.fromScale(hue, 0.5)
			onChange(Color3.fromHSV(hue, saturation, value))
		end

		marker.Position = UDim2.fromScale(saturation, 1 - value)
		hueMarker.Position = UDim2.fromScale(hue, 0.5)

		table.insert(connections, square.InputBegan:Connect(function(input)
			if not isPress(input) then
				return
			end

			local function update(moved)
				saturation = math.clamp((moved.Position.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)
				value = 1 - math.clamp((moved.Position.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)
				refresh()
			end

			activeDrag = update
			update(input)
		end))

		table.insert(connections, bar.InputBegan:Connect(function(input)
			if not isPress(input) then
				return
			end

			local function update(moved)
				hue = math.clamp((moved.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 0.999)
				refresh()
			end

			activeDrag = update
			update(input)
		end))
	end

	local Section = {}
	Section.__index = Section

	local function newRow(section, height)
		return make("Frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			Parent = section.holder,
		})
	end

	local function controlBox(parent, position, size)
		local box = make("TextButton", {
			Position = position,
			Size = size,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Parent = parent,
		})

		round(box, 8)

		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(36, 36, 43), Color3.fromRGB(24, 24, 29)),
			Rotation = 90,
			Parent = box,
		})

		local stroke = addStroke(box, THEME.line)
		local scale = make("UIScale", { Scale = 1, Parent = box })

		hoverEffect(box, function()
			tweenTo(stroke, 0.12, { Color = THEME.accentDark })
		end, function()
			tweenTo(stroke, 0.12, { Color = THEME.line })
		end)

		return box, stroke, scale
	end

	function Section:AddLabel(text, options)
		options = options or {}

		if options.wrap then
			local wrapRow = make("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = self.holder,
			})

			local wrapLabel = textLabel({
				Position = UDim2.fromOffset(2, 0),
				Size = UDim2.new(1, -4, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = text,
				TextSize = 10,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = wrapRow,
			})

			return {
				SetText = function(_, value)
					wrapLabel.Text = value
				end,
			}
		end

		local row = newRow(self, 16)

		local label = textLabel({
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Text = text,
			Parent = row,
		})

		addTooltipMark(row, label, text, options.tooltip)

		return {
			SetText = function(_, value)
				label.Text = value
			end,
		}
	end

	function Section:AddButton(text, callback, options)
		options = options or {}

		local danger = options.danger == true
		local row = newRow(self, 26)

		local button = make("TextButton", {
			Size = UDim2.new(1, 0, 1, -3),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Text = text,
			TextColor3 = danger and THEME.accentLight or THEME.textBright,
			TextSize = 11,
			Font = FONT_BOLD,
			AutoButtonColor = false,
			Parent = row,
		})

		round(button, 8)

		make("UIGradient", {
			Color = danger and ColorSequence.new(Color3.fromRGB(78, 26, 36), Color3.fromRGB(46, 16, 22))
				or ColorSequence.new(Color3.fromRGB(40, 40, 48), Color3.fromRGB(26, 26, 32)),
			Rotation = 90,
			Parent = button,
		})

		local stroke = addStroke(button, danger and THEME.accentDark or THEME.line)
		local scale = make("UIScale", { Scale = 1, Parent = button })

		hoverEffect(button, function()
			tweenTo(stroke, 0.12, { Color = THEME.accent })
		end, function()
			tweenTo(stroke, 0.12, { Color = danger and THEME.accentDark or THEME.line })
		end)

		pressEffect(button, scale)

		if callback then
			table.insert(connections, button.Activated:Connect(function()
				task.spawn(callback)
			end))
		end

		return button
	end

	function Section:AddToggle(text, default, callback, options)
		options = options or {}

		local toggle = { Value = default == true, Callback = callback, rightOffset = 2 }
		local row = newRow(self, 18)
		local indent = options.indent and 14 or 0
		local trackWidth = 28
		local trackHeight = 15
		local trackX = indent + 2

		local function pill(width, height, transparency, color)
			local frame = make("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromOffset(trackX - (width - trackWidth) / 2, 9),
				Size = UDim2.fromOffset(width, height),
				BackgroundColor3 = color,
				BackgroundTransparency = transparency,
				BorderSizePixel = 0,
				Parent = row,
			})

			round(frame, height)
			return frame
		end

		local glowOuter = pill(44, 28, 1, THEME.accent)
		local glowInner = pill(36, 22, 1, THEME.accent)
		local box = pill(trackWidth, trackHeight, 0, Color3.new(1, 1, 1))
		local boxStroke = addStroke(box, THEME.line)

		local boxGradient = make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(38, 38, 45), Color3.fromRGB(26, 26, 31)),
			Rotation = 90,
			Parent = box,
		})

		local knob = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.fromOffset(11, 11),
			BackgroundColor3 = THEME.text,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = box,
		})

		round(knob, 999)

		local button = make("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			Parent = row,
		})

		local label = textLabel({
			Position = UDim2.fromOffset(indent + 38, 0),
			Size = UDim2.new(1, -(indent + 38), 1, 0),
			Text = text,
			Parent = row,
		})

		addTooltipMark(row, label, text, options.tooltip)

		function toggle:Set(value, silent)
			self.Value = value == true

			boxGradient.Color = self.Value and ColorSequence.new(THEME.accentLight, THEME.accent) or ColorSequence.new(Color3.fromRGB(38, 38, 45), Color3.fromRGB(26, 26, 31))
			boxStroke.Color = self.Value and THEME.accent or THEME.line
			label.TextColor3 = self.Value and THEME.textBright or THEME.text

			tweenTo(knob, 0.16, {
				Position = UDim2.new(0, self.Value and 15 or 2, 0.5, 0),
				BackgroundColor3 = self.Value and Color3.new(1, 1, 1) or THEME.text,
			}, Enum.EasingStyle.Back)

			tweenTo(glowOuter, 0.2, { BackgroundTransparency = self.Value and 0.9 or 1 })
			tweenTo(glowInner, 0.2, { BackgroundTransparency = self.Value and 0.74 or 1 })

			if not silent and self.Callback then
				task.spawn(self.Callback, self.Value)
			end
		end

		function toggle:AddKeybind(defaultKey, flag)
			local bind = { Key = nil }

			local keyButton = make("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -self.rightOffset, 0.5, 0),
				Size = UDim2.fromOffset(44, 15),
				BackgroundColor3 = THEME.control,
				BorderSizePixel = 0,
				Text = "Bind",
				TextColor3 = THEME.text,
				TextSize = 9,
				Font = FONT_BOLD,
				AutoButtonColor = false,
				ZIndex = 3,
				Parent = row,
			})

			round(keyButton, 7)
			addStroke(keyButton, THEME.line)
			self.rightOffset += 48

			local function describe(key)
				if typeof(key) == "EnumItem" then
					return key.Name
				end

				return "Bind"
			end

			function bind:Set(key)
				self.Key = key
				keyButton.Text = describe(key)
				keyButton.TextColor3 = key and THEME.accentLight or THEME.text
			end

			bind.Toggle = toggle
			bind.Button = keyButton
			bind.Describe = describe
			table.insert(binds, bind)

			table.insert(connections, keyButton.Activated:Connect(function()
				listeningBind = bind
				keyButton.Text = "..."
			end))

			registerFlag(flag, function()
				return bind.Key and bind.Key.Name or false
			end, function(name)
				bind:Set(name and Enum.KeyCode[name] or nil)
			end)

			if defaultKey then
				bind:Set(defaultKey)
			end

			return self
		end

		function toggle:AddColor(defaultColor, onChange, flag)
			local color = defaultColor or THEME.accent

			local swatch = make("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -self.rightOffset, 0.5, 0),
				Size = UDim2.fromOffset(26, 12),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 3,
				Parent = row,
			})

			round(swatch, 6)
			addStroke(swatch, THEME.line)
			self.rightOffset += 30

			table.insert(connections, swatch.Activated:Connect(function()
				openColorPicker(swatch, color, function(newColor)
					color = newColor
					swatch.BackgroundColor3 = newColor

					if onChange then
						onChange(newColor)
					end
				end)
			end))

			registerFlag(flag, function()
				return { color.R, color.G, color.B }
			end, function(value)
				if type(value) == "table" then
					color = Color3.new(value[1], value[2], value[3])
					swatch.BackgroundColor3 = color

					if onChange then
						onChange(color)
					end
				end
			end)

			return self
		end

		table.insert(connections, button.Activated:Connect(function()
			toggle:Set(not toggle.Value)

			if ui.onToggleClick then
				ui.onToggleClick(toggle.Value)
			end
		end))

		registerFlag(options.flag, function()
			return toggle.Value
		end, function(value)
			toggle:Set(value == true)
		end)

		toggle:Set(toggle.Value, true)
		return toggle
	end

	function Section:AddSlider(text, minimum, maximum, default, rounding, callback, options)
		options = options or {}

		local slider = { Value = default, Callback = callback }
		local row = newRow(self, 32)

		local label = textLabel({
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -70, 0, 16),
			Text = text,
			TextColor3 = THEME.textBright,
			Parent = row,
		})

		local chip = make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -2, 0, 0),
			Size = UDim2.fromOffset(54, 15),
			BackgroundColor3 = THEME.control,
			BorderSizePixel = 0,
			Parent = row,
		})

		round(chip, 8)

		local valueLabel = textLabel({
			Size = UDim2.fromScale(1, 1),
			TextColor3 = THEME.accentLight,
			TextSize = 10,
			Font = FONT_BOLD,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = chip,
		})

		addTooltipMark(row, label, text, options.tooltip)

		local track = make("Frame", {
			Position = UDim2.fromOffset(4, 23),
			Size = UDim2.new(1, -8, 0, 5),
			BackgroundColor3 = THEME.control,
			BorderSizePixel = 0,
			Parent = row,
		})

		round(track, 3)

		local fill = make("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = track,
		})

		round(fill, 3)
		make("UIGradient", { Color = ColorSequence.new(THEME.accentDark, THEME.accentLight), Parent = fill })

		local glow = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = THEME.accent,
			BackgroundTransparency = 0.78,
			BorderSizePixel = 0,
			Parent = track,
		})

		round(glow, 999)

		local thumb = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = track,
		})

		round(thumb, 999)
		make("UIStroke", { Color = THEME.accent, Thickness = 2, Parent = thumb })

		local hit = make("TextButton", {
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "",
			Parent = row,
		})

		local function render(animate)
			local fraction = (slider.Value - minimum) / (maximum - minimum)
			local fillGoal = UDim2.fromScale(fraction, 1)
			local thumbGoal = UDim2.new(fraction, 0, 0.5, 0)

			if animate then
				tweenTo(fill, 0.08, { Size = fillGoal })
				tweenTo(thumb, 0.08, { Position = thumbGoal })
				tweenTo(glow, 0.08, { Position = thumbGoal })
			else
				fill.Size = fillGoal
				thumb.Position = thumbGoal
				glow.Position = thumbGoal
			end

			if options.disabledAtMin and slider.Value <= minimum then
				valueLabel.Text = "Off"
			else
				valueLabel.Text = tostring(slider.Value) .. (options.suffix or "")
			end
		end

		function slider:Set(value, silent)
			local factor = 10 ^ rounding
			value = math.clamp(math.floor(value * factor + 0.5) / factor, minimum, maximum)
			self.Value = value
			render(false)

			if not silent and self.Callback then
				task.spawn(self.Callback, value)
			end
		end

		table.insert(connections, hit.InputBegan:Connect(function(input)
			if not isPress(input) then
				return
			end

			local function update(moved)
				local fraction = math.clamp((moved.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				local factor = 10 ^ rounding
				local value = math.clamp(math.floor((minimum + (maximum - minimum) * fraction) * factor + 0.5) / factor, minimum, maximum)

				slider.Value = value
				render(true)

				if slider.Callback then
					task.spawn(slider.Callback, value)
				end
			end

			tweenTo(thumb, 0.1, { Size = UDim2.fromOffset(15, 15) })
			tweenTo(glow, 0.1, { Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0.65 })

			activeDrag = update
			activeEnd = function()
				tweenTo(thumb, 0.12, { Size = UDim2.fromOffset(12, 12) })
				tweenTo(glow, 0.12, { Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0.78 })
			end

			update(input)
		end))

		registerFlag(options.flag, function()
			return slider.Value
		end, function(value)
			slider:Set(tonumber(value) or default)
		end)

		slider:Set(default, true)
		return slider
	end

	function Section:AddDropdown(text, values, default, callback, options)
		options = options or {}

		local multi = options.multi == true
		local dropdown = { Callback = callback, Values = values }
		local row = newRow(self, 40)

		dropdown.Value = multi and {} or default

		if multi and type(default) == "table" then
			for _, name in next, default do
				dropdown.Value[name] = true
			end
		end

		local label = textLabel({
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -4, 0, 15),
			Text = text,
			TextColor3 = THEME.textBright,
			Parent = row,
		})

		addTooltipMark(row, label, text, options.tooltip)

		local box, boxStroke = controlBox(row, UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 21))

		local valueLabel = textLabel({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -26, 1, 0),
			TextSize = 10,
			TextColor3 = THEME.textBright,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = box,
		})

		local arrow = make("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(12, 12),
			BackgroundTransparency = 1,
			Parent = box,
		})

		makeIcon(arrow, multi and "plus" or "chevron", THEME.accentLight, 10, UDim2.fromOffset(1, 1))

		local function describe()
			if not multi then
				return tostring(dropdown.Value or "Select...")
			end

			local names = {}

			for _, name in next, values do
				if dropdown.Value[name] then
					table.insert(names, name)
				end
			end

			return #names > 0 and table.concat(names, ", ") or "None"
		end

		function dropdown:Set(value, silent)
			self.Value = value
			valueLabel.Text = describe()

			if not silent and self.Callback then
				task.spawn(self.Callback, self.Value)
			end
		end

		function dropdown:SetValues(newValues)
			values = newValues
			self.Values = newValues

			if multi then
				local filtered = {}

				for _, name in next, newValues do
					if self.Value[name] then
						filtered[name] = true
					end
				end

				self.Value = filtered
			elseif self.Value and not table.find(newValues, self.Value) then
				self.Value = nil
			end

			valueLabel.Text = describe()
		end

		table.insert(connections, box.Activated:Connect(function()
			local rows = math.min(#values, MAX_LIST_ROWS)

			if rows == 0 then
				return
			end

			tweenTo(arrow, 0.15, { Rotation = 180 })
			tweenTo(boxStroke, 0.15, { Color = THEME.accent })

			local popup = beginPopup(box, box.AbsoluteSize.X, rows * 20 + 6, function()
				tweenTo(arrow, 0.15, { Rotation = 0 })
				tweenTo(boxStroke, 0.15, { Color = THEME.line })
			end)

			local scroll = make("ScrollingFrame", {
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.new(1, -6, 1, -6),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = THEME.accent,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ZIndex = 53,
				Parent = popup,
			})

			make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

			local items = {}
			local marks = {}

			local function paint()
				for name, item in next, items do
					local selected = multi and dropdown.Value[name] or (not multi and dropdown.Value == name)

					item.TextColor3 = selected and THEME.accentLight or THEME.text
					item.BackgroundTransparency = selected and 0.88 or 1
					marks[name].Visible = selected and true or false
				end
			end

			for index, name in next, values do
				local item = make("TextButton", {
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundColor3 = THEME.accent,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = name,
					TextColor3 = THEME.text,
					TextSize = 10,
					Font = FONT,
					TextXAlignment = Enum.TextXAlignment.Left,
					AutoButtonColor = false,
					LayoutOrder = index,
					ZIndex = 54,
					Parent = scroll,
				})

				round(item, 6)
				make("UIPadding", { PaddingLeft = UDim.new(0, 18), Parent = item })

				local mark = make("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, -10, 0.5, 0),
					Size = UDim2.fromOffset(5, 5),
					BackgroundColor3 = THEME.accentLight,
					BorderSizePixel = 0,
					Visible = false,
					ZIndex = 55,
					Parent = item,
				})

				round(mark, 999)
				items[name] = item
				marks[name] = mark

				table.insert(connections, item.Activated:Connect(function()
					if multi then
						local copy = table.clone(dropdown.Value)
						copy[name] = not copy[name] or nil
						dropdown:Set(copy)
						paint()
					else
						dropdown:Set(name)
						closePopup()
					end
				end))
			end

			paint()
		end))

		registerFlag(options.flag, function()
			if not multi then
				return dropdown.Value
			end

			local names = {}

			for name in next, dropdown.Value do
				table.insert(names, name)
			end

			return names
		end, function(value)
			if multi then
				local map = {}

				for _, name in next, type(value) == "table" and value or {} do
					map[name] = true
				end

				dropdown:Set(map)
			else
				dropdown:Set(value)
			end
		end)

		dropdown:Set(dropdown.Value, true)
		return dropdown
	end

	function Section:AddInput(text, default, callback, placeholder, options)
		options = options or {}

		local input = { Value = tostring(default or ""), Callback = callback }
		local row = newRow(self, 40)

		textLabel({
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -4, 0, 15),
			Text = text,
			TextColor3 = THEME.textBright,
			Parent = row,
		})

		local holder = make("Frame", {
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 21),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = row,
		})

		round(holder, 8)

		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(36, 36, 43), Color3.fromRGB(24, 24, 29)),
			Rotation = 90,
			Parent = holder,
		})

		local stroke = addStroke(holder, THEME.line)

		local box = make("TextBox", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, 0),
			BackgroundTransparency = 1,
			Text = input.Value,
			PlaceholderText = placeholder or "",
			PlaceholderColor3 = THEME.text,
			TextColor3 = THEME.textBright,
			TextSize = 10,
			Font = FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			Parent = holder,
		})

		function input:Set(value, silent)
			self.Value = tostring(value or "")
			box.Text = self.Value

			if not silent and self.Callback then
				task.spawn(self.Callback, self.Value)
			end
		end

		table.insert(connections, box.Focused:Connect(function()
			tweenTo(stroke, 0.15, { Color = THEME.accent })
		end))

		table.insert(connections, box.FocusLost:Connect(function()
			tweenTo(stroke, 0.15, { Color = THEME.line })
			input:Set(box.Text)
		end))

		registerFlag(options.flag, function()
			return input.Value
		end, function(value)
			input:Set(value)
		end)

		return input
	end

	function Section:AddColor(text, default, callback, options)
		options = options or {}

		local color = default or THEME.accent
		local row = newRow(self, 18)

		textLabel({
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -36, 1, 0),
			Text = text,
			Parent = row,
		})

		local swatch = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(28, 13),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Parent = row,
		})

		round(swatch, 7)

		local stroke = addStroke(swatch, THEME.line)

		hoverEffect(swatch, function()
			tweenTo(stroke, 0.12, { Color = THEME.textBright })
		end, function()
			tweenTo(stroke, 0.12, { Color = THEME.line })
		end)

		table.insert(connections, swatch.Activated:Connect(function()
			openColorPicker(swatch, color, function(newColor)
				color = newColor
				swatch.BackgroundColor3 = newColor

				if callback then
					callback(newColor)
				end
			end)
		end))

		local object = { Value = color }

		function object:Set(newColor, silent)
			color = newColor
			self.Value = newColor
			swatch.BackgroundColor3 = newColor

			if not silent and callback then
				callback(newColor)
			end
		end

		registerFlag(options.flag, function()
			return { color.R, color.G, color.B }
		end, function(value)
			if type(value) == "table" then
				object:Set(Color3.new(value[1], value[2], value[3]))
			end
		end)

		return object
	end

	function Section:AddKeybind(text, default, callback, options)
		options = options or {}

		local row = newRow(self, 18)

		textLabel({
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -80, 1, 0),
			Text = text,
			Parent = row,
		})

		local keyButton = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(76, 16),
			BackgroundColor3 = THEME.control,
			BorderSizePixel = 0,
			Text = "",
			TextColor3 = THEME.accentLight,
			TextSize = 9,
			Font = FONT_BOLD,
			AutoButtonColor = false,
			Parent = row,
		})

		round(keyButton, 8)
		addStroke(keyButton, THEME.line)

		local bind = { Key = default, Button = keyButton }

		function bind.Describe(key)
			if typeof(key) == "EnumItem" then
				return key.Name
			end

			return "None"
		end

		function bind:Set(key)
			self.Key = key
			keyButton.Text = self.Describe(key)

			if callback then
				callback(key)
			end
		end

		table.insert(connections, keyButton.Activated:Connect(function()
			listeningBind = bind
			keyButton.Text = "..."
		end))

		registerFlag(options.flag, function()
			return bind.Key and bind.Key.Name or false
		end, function(name)
			bind:Set(name and Enum.KeyCode[name] or nil)
		end)

		keyButton.Text = bind.Describe(default)

		if default and callback then
			callback(default)
		end

		return bind
	end

	function Section:AddGrid(options)
		options = options or {}

		local cell = options.cell or 62
		local grid = { tiles = {} }

		local searchRow = newRow(self, 24)

		local searchHolder = make("Frame", {
			Size = UDim2.new(1, 0, 1, -3),
			BackgroundColor3 = THEME.control,
			BorderSizePixel = 0,
			Parent = searchRow,
		})

		round(searchHolder, 8)
		addStroke(searchHolder, THEME.line)

		local searchBox = make("TextBox", {
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			PlaceholderText = options.placeholder or "Search...",
			PlaceholderColor3 = THEME.text,
			TextColor3 = THEME.textBright,
			TextSize = 10,
			Font = FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			Parent = searchHolder,
		})

		local scrollRow = newRow(self, options.height or 190)

		local scroll = make("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = THEME.accent,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = scrollRow,
		})

		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell, cell + 18),
			CellPadding = UDim2.fromOffset(4, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = scroll,
		})

		make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = scroll })

		function grid:Clear()
			for _, entry in next, self.tiles do
				entry.tile:Destroy()
			end

			self.tiles = {}
		end

		function grid:SetItems(items)
			self:Clear()

			for index, item in ipairs(items) do
				local tile = make("TextButton", {
					Name = tostring(item.key),
					LayoutOrder = index,
					Text = "",
					AutoButtonColor = false,
					BackgroundColor3 = Color3.fromRGB(10, 10, 13),
					BackgroundTransparency = 0.25,
					BorderSizePixel = 0,
					Parent = scroll,
				})

				round(tile, 10)

				local stroke = make("UIStroke", {
					Thickness = 1.5,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = item.color or Color3.new(1, 1, 1),
					Transparency = 0.55,
					Parent = tile,
				})

				make("ImageLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 4),
					Size = UDim2.fromOffset(cell - 14, cell - 14),
					Image = item.image or "",
					ScaleType = Enum.ScaleType.Fit,
					Parent = tile,
				})

				textLabel({
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -3),
					Size = UDim2.new(1, -6, 0, 20),
					Text = item.name,
					Font = FONT_BOLD,
					TextSize = 9,
					TextWrapped = true,
					TextColor3 = THEME.textBright,
					TextXAlignment = Enum.TextXAlignment.Center,
					Parent = tile,
				})

				if item.tag then
					local tag = make("Frame", {
						Position = UDim2.fromOffset(3, 3),
						Size = UDim2.fromOffset(34, 11),
						BackgroundColor3 = Color3.new(0, 0, 0),
						BackgroundTransparency = 0.3,
						BorderSizePixel = 0,
						ZIndex = 3,
						Parent = tile,
					})

					round(tag, 4)

					textLabel({
						Size = UDim2.fromScale(1, 1),
						Text = item.tag,
						Font = FONT_BOLD,
						TextSize = 8,
						TextColor3 = Color3.new(1, 1, 1),
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 4,
						Parent = tag,
					})
				end

				hoverEffect(tile, function()
					tweenTo(stroke, 0.12, { Transparency = 0.1 })
				end, function()
					tweenTo(stroke, 0.12, { Transparency = 0.55 })
				end)

				table.insert(connections, tile.Activated:Connect(function()
					if options.onSelect then
						task.spawn(options.onSelect, item)
					end
				end))

				table.insert(self.tiles, { tile = tile, search = string.lower(item.name .. " " .. tostring(item.key)) })
			end

			self:Filter(searchBox.Text)
		end

		function grid:Filter(query)
			query = string.lower(query or "")

			for _, entry in next, self.tiles do
				entry.tile.Visible = query == "" or entry.search:find(query, 1, true) ~= nil
			end
		end

		table.insert(connections, searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			grid:Filter(searchBox.Text)
		end))

		return grid
	end

	local Tab = {}
	Tab.__index = Tab

	function Tab:AddSection(name, column)
		local holderColumn = column == "full" and self.full or self.columns[column or 1]

		local frame = make("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = holderColumn,
		})

		round(frame, 12)
		addStroke(frame, THEME.line)

		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(28, 28, 34), Color3.fromRGB(18, 18, 22)),
			Rotation = 90,
			Parent = frame,
		})

		textLabel({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 0, 28),
			Text = name,
			TextColor3 = THEME.textBright,
			Font = FONT_BOLD,
			TextSize = 11,
			Parent = frame,
		})

		local line = make("Frame", {
			Position = UDim2.fromOffset(8, 28),
			Size = UDim2.new(1, -16, 0, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = frame,
		})

		make("UIGradient", {
			Color = ColorSequence.new(THEME.accent, THEME.accentDark),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = line,
		})

		local holder = make("Frame", {
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = frame,
		})

		make("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = holder,
		})

		make("UIPadding", {
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 9),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			Parent = holder,
		})

		return setmetatable({ holder = holder }, Section)
	end

	local function selectTab(tab)
		closePopup()

		for _, other in next, tabs do
			local active = other == tab

			other.content.Visible = active
			tweenTo(other.bar, 0.18, { Size = UDim2.new(0, 3, active and 1 or 0, active and -10 or 0) })
			tweenTo(other.background, 0.18, { BackgroundTransparency = active and 0.78 or 1 })
			other.label.TextColor3 = active and THEME.textBright or THEME.text
		end
	end

	local function addTab(name)
		local tab = setmetatable({}, Tab)

		tab.button = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = #tabs + 1,
			Parent = sidebar,
		})

		tab.background = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = tab.button,
		})

		round(tab.background, 9)

		make("UIGradient", {
			Color = ColorSequence.new(THEME.accent, THEME.accentDark),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = tab.background,
		})

		tab.bar = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 3, 0, 0),
			BackgroundColor3 = THEME.accentLight,
			BorderSizePixel = 0,
			Parent = tab.button,
		})

		round(tab.bar, 2)

		tab.label = textLabel({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -16, 1, 0),
			Text = name,
			TextColor3 = THEME.text,
			Font = FONT_BOLD,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = tab.button,
		})

		tab.content = make("ScrollingFrame", {
			Position = UDim2.fromOffset(SIDEBAR_W + 9, 48),
			Size = UDim2.new(1, -(SIDEBAR_W + 17), 1, -56),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = THEME.accent,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = window,
		})

		local body = make("Frame", {
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = tab.content,
		})

		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })

		tab.full = make("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = body,
		})

		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tab.full })

		local columnsHolder = make("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = body,
		})

		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = columnsHolder,
		})

		tab.columns = {}

		for index = 1, 2 do
			local column = make("Frame", {
				Size = UDim2.new(1 / 2, -3, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Parent = columnsHolder,
			})

			make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = column })
			tab.columns[index] = column
		end

		hoverEffect(tab.button, function()
			if tab.content.Visible == false then
				tweenTo(tab.background, 0.12, { BackgroundTransparency = 0.92 })
			end
		end, function()
			if tab.content.Visible == false then
				tweenTo(tab.background, 0.12, { BackgroundTransparency = 1 })
			end
		end)

		table.insert(connections, tab.button.Activated:Connect(function()
			selectTab(tab)
		end))

		table.insert(tabs, tab)
		return tab
	end

	local function setMenuVisible(visible)
		root.Visible = visible

		if visible then
			dim.Visible = true
			windowScale.Scale = 0.94
			tweenTo(windowScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			tweenTo(dim, 0.25, { BackgroundTransparency = 0.5 })

			if blur then
				tweenTo(blur, 0.3, { Size = 10 })
			end
		else
			closePopup()
			tweenTo(dim, 0.25, { BackgroundTransparency = 1 })

			if blur then
				tweenTo(blur, 0.25, { Size = 0 })
			end

			task.delay(0.25, function()
				if not root.Visible then
					dim.Visible = false
				end
			end)
		end
	end

	local menuButton = make("TextButton", {
		Name = "MenuButton",
		Position = UDim2.new(0, 12, 0.5, -22),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Text = "M",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 19,
		Font = FONT_BOLD,
		AutoButtonColor = false,
		Active = true,
		ZIndex = 5,
		Parent = gui,
	})

	round(menuButton, 999)

	make("UIGradient", {
		Color = ColorSequence.new(THEME.accentLight, Color3.fromRGB(150, 30, 48)),
		Rotation = 45,
		Parent = menuButton,
	})

	addStroke(menuButton, Color3.fromRGB(255, 160, 175)).Thickness = 1.5

	local pulse = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.accent,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = menuButton,
	})

	round(pulse, 999)

	tweenService:Create(pulse, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false), {
		Size = UDim2.fromScale(1.7, 1.7),
		BackgroundTransparency = 1,
	}):Play()

	table.insert(connections, menuButton.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end

		local start = input.Position
		local origin = menuButton.Position
		local moved = false

		activeDrag = function(current)
			local delta = current.Position - start

			if delta.Magnitude > 8 and not menuLocked then
				moved = true
			end

			if moved then
				menuButton.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
			end
		end

		local connection = nil

		connection = input.Changed:Connect(function()
			if input.UserInputState ~= Enum.UserInputState.End then
				return
			end

			connection:Disconnect()

			if not moved then
				setMenuVisible(not root.Visible)
			end
		end)
	end))

	table.insert(connections, userInputService.InputBegan:Connect(function(input, processed)
		if listeningBind then
			local bind = listeningBind
			listeningBind = nil

			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
					bind:Set(nil)
				else
					bind:Set(input.KeyCode)
				end
			else
				bind.Button.Text = bind.Describe(bind.Key)
			end

			return
		end

		if processed then
			return
		end

		if menuKey and input.KeyCode == menuKey then
			setMenuVisible(not root.Visible)
			return
		end

		for _, bind in next, binds do
			if bind.Key and input.KeyCode == bind.Key then
				bind.Toggle:Set(not bind.Toggle.Value)
			end
		end
	end))

	local toastHolder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 80,
		Parent = gui,
	})

	make("UIListLayout", {
		Padding = UDim.new(0, 5),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastHolder,
	})

	local toastOrder = 0

	function ui.Notify(title, content)
		if not ui.notificationsEnabled or not toastHolder.Parent then
			return false
		end

		toastOrder += 1

		local text = content and ("<b>" .. escapeRich(title) .. "</b>  " .. escapeRich(content)) or escapeRich(title)

		local toast = make("Frame", {
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = toastOrder,
			ZIndex = 81,
			Parent = toastHolder,
		})

		round(toast, 10)

		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(34, 20, 26), Color3.fromRGB(16, 16, 20)),
			Rotation = 90,
			Parent = toast,
		})

		local stroke = addStroke(toast, THEME.accent)
		stroke.Transparency = 1

		make("UIPadding", {
			PaddingLeft = UDim.new(0, 26),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			Parent = toast,
		})

		make("UISizeConstraint", { MaxSize = Vector2.new(320, 120), Parent = toast })

		local dot = make("Frame", {
			Position = UDim2.fromOffset(-16, 6),
			Size = UDim2.fromOffset(7, 7),
			BackgroundColor3 = THEME.accentLight,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 82,
			Parent = toast,
		})

		round(dot, 999)

		local message = textLabel({
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Text = text,
			RichText = true,
			TextColor3 = THEME.textBright,
			TextTransparency = 1,
			TextWrapped = true,
			ZIndex = 82,
			Parent = toast,
		})

		tweenTo(toast, 0.25, { BackgroundTransparency = 0.05 })
		tweenTo(stroke, 0.25, { Transparency = 0.4 })
		tweenTo(dot, 0.25, { BackgroundTransparency = 0 })
		tweenTo(message, 0.25, { TextTransparency = 0 })

		task.delay(4, function()
			if not toast.Parent then
				return
			end

			tweenTo(toast, 0.3, { BackgroundTransparency = 1 })
			tweenTo(stroke, 0.3, { Transparency = 1 })
			tweenTo(dot, 0.3, { BackgroundTransparency = 1 })
			tweenTo(message, 0.3, { TextTransparency = 1 })

			task.delay(0.35, function()
				toast:Destroy()
			end)
		end)

		return true
	end

	local function ensureFolders()
		if makefolder and isfolder then
			for _, path in ipairs({ "MagmaMM2", CONFIG_DIR }) do
				if not isfolder(path) then
					pcall(makefolder, path)
				end
			end
		end
	end

	function ui.Snapshot()
		local data = {}

		for flag, entry in next, ui.flags do
			local ok, value = pcall(entry.get)

			if ok and value ~= nil then
				data[flag] = value
			end
		end

		if ui.onSave then
			local ok, extra = pcall(ui.onSave)

			if ok then
				data.__extra = extra
			end
		end

		local ok, encoded = pcall(function()
			return httpService:JSONEncode(data)
		end)

		return ok and encoded or ""
	end

	function ui.SaveConfig(name)
		if not writefile then
			return false
		end

		ensureFolders()
		local encoded = ui.Snapshot()

		if encoded == "" then
			return false
		end

		return (pcall(writefile, CONFIG_DIR .. "/" .. name .. ".json", encoded))
	end

	function ui.LoadConfig(name)
		local path = CONFIG_DIR .. "/" .. name .. ".json"

		if not (isfile and readfile and isfile(path)) then
			return false
		end

		local ok, data = pcall(function()
			return httpService:JSONDecode(readfile(path))
		end)

		if not ok or type(data) ~= "table" then
			return false
		end

		ui.loading = true

		if data.__extra and ui.onLoad then
			pcall(ui.onLoad, data.__extra)
		end

		for flag, entry in next, ui.flags do
			if data[flag] ~= nil then
				pcall(entry.set, data[flag])
			end
		end

		task.delay(0.5, function()
			ui.loading = false
		end)

		return true
	end

	function ui.DeleteConfig(name)
		local path = CONFIG_DIR .. "/" .. name .. ".json"

		if delfile and isfile and isfile(path) then
			return (pcall(delfile, path))
		end

		return false
	end

	function ui.ListConfigs()
		local names = {}

		if listfiles and isfolder and isfolder(CONFIG_DIR) then
			for _, path in ipairs(listfiles(CONFIG_DIR)) do
				local name = tostring(path):match("([^/\\]+)%.json$")

				if name and name ~= "autosave" then
					table.insert(names, name)
				end
			end
		end

		table.sort(names)
		return names
	end

	ui.Gui = gui
	ui.Window = window
	ui.Tabs = tabs
	ui.AddTab = addTab
	ui.SelectTab = selectTab
	ui.SetMenuVisible = setMenuVisible
	ui.MenuButton = menuButton
	ui.MenuHome = menuButton.Position

	function ui.SetMenuKey(key)
		menuKey = key
	end

	function ui.SetMenuLocked(value)
		menuLocked = value == true
	end

	function ui.OnDestroy(callback)
		table.insert(destroyCallbacks, callback)
	end

	function ui.Destroy()
		for _, callback in ipairs(destroyCallbacks) do
			pcall(callback)
		end

		for _, connection in next, connections do
			pcall(function()
				connection:Disconnect()
			end)
		end

		if blur then
			blur:Destroy()
			blur = nil
		end

		gui:Destroy()
	end

	return ui
end

return Magma

end)()

local function magmaMain()
local MESH_URL = "https://raw.githubusercontent.com/kroxn/visual/refs/heads/main/weapon.lua"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local guiRoot = (type(gethui) == "function" and gethui()) or CoreGui
local requestFunction = request or http_request or (syn and syn.request) or (http and http.request)
local IS_MOBILE = UserInputService.TouchEnabled
local placeId = game.PlaceId
local jobId = game.JobId

local connections = {}
local alive = true
local booting = true

local function track(connection)
	connections[#connections + 1] = connection
	return connection
end

local function disconnectAll(list)
	for index = #list, 1, -1 do
		pcall(function()
			list[index]:Disconnect()
		end)

		list[index] = nil
	end
end

local function safeRequire(getter)
	local ok, result = pcall(function()
		return require(getter())
	end)

	return ok and type(result) == "table" and result or nil
end

local function httpGet(url)
	if requestFunction then
		local ok, response = pcall(requestFunction, { Url = url, Method = "GET" })

		if ok and type(response) == "table" and type(response.Body) == "string" and #response.Body > 0 then
			return response.Body
		end
	end

	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)

	if ok and type(body) == "string" and #body > 0 then
		return body
	end

	return nil
end

local function httpJson(url)
	local body = httpGet(url)

	if not body then
		return nil
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	return ok and data or nil
end

------------------------------------------------------------------ UI bootstrap

local ui = Magma.new("MM2")
local els = {}

------------------------------------------------------------------ sounds / notify

local SFX_IDS = {
	error = 131039887376992,
	gun = 131390520971848,
	click = 139800881181209,
	toggle = 136108770017536,
}

local SFX_VOLUME = { error = 0.55, gun = 0.75, click = 0.65, toggle = 0.6 }
local sfxOn = { error = true, gun = true, click = true, toggle = true }
local sfxCache = {}

local function playSfx(name)
	if not sfxOn[name] or booting or ui.loading then
		return
	end

	pcall(function()
		local folder = SoundService:FindFirstChild("MagmaSFX")

		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "MagmaSFX"
			folder.Parent = SoundService
		end

		local sound = sfxCache[name]

		if not sound or not sound.Parent then
			sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = "rbxassetid://" .. SFX_IDS[name]
			sound.Volume = SFX_VOLUME[name] or 0.5
			sound.Parent = folder
			sfxCache[name] = sound
		end

		sound.TimePosition = 0
		sound:Play()
	end)
end

local function notify(title, content, kind)
	if booting or ui.loading then
		return
	end

	if kind == "error" then
		playSfx("error")
	end

	ui.Notify(title, content)
end

ui.onToggleClick = function()
	playSfx("toggle")
end

------------------------------------------------------------------ helpers

local function getHumanoid()
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player)
	local character = player and player.Character
	return character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
end

local function isAlive(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function findMap()
	local found = nil

	for _, child in ipairs(Workspace:GetChildren()) do
		if child:FindFirstChild("CoinAreas") or child:FindFirstChild("CoinContainer") then
			found = child
		end
	end

	return found
end

local function inLobby()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local main = playerGui and playerGui:FindFirstChild("MainGUI")
	local gameFrame = main and main:FindFirstChild("Game")

	if not gameFrame then
		return true
	end

	return gameFrame:FindFirstChild("Inventory") == nil
end

local function tagPassthrough(instance)
	pcall(function()
		CollectionService:AddTag(instance, "WeaponPassthrough")
	end)
end

local function comma(value)
	local number = tonumber(value)

	if number == nil then
		return "?"
	end

	local sign = number < 0 and "-" or ""
	local text = tostring(math.floor(math.abs(number)))
	return sign .. text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

------------------------------------------------------------------ roles

local roundData = nil

local function findHolder(toolName, roleName)
	for _, player in ipairs(Players:GetPlayers()) do
		local backpack = player:FindFirstChildOfClass("Backpack")

		if backpack and backpack:FindFirstChild(toolName) then
			return player
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild(toolName) then
			return player
		end
	end

	if roundData then
		for name, data in pairs(roundData) do
			if type(data) == "table" and data.Role == roleName and Players:FindFirstChild(name) then
				return Players:FindFirstChild(name)
			end
		end
	end

	return nil
end

local function getMurderer()
	return findHolder("Knife", "Murderer")
end

local function getSheriff()
	return findHolder("Gun", "Sheriff")
end

------------------------------------------------------------------ ESP

local ESP = {
	outline = false,
	fill = false,
	names = false,
	gun = false,
	trap = false,
	groups = {},
	revealed = {},
	looping = false,
	colors = {
		murderer = Color3.fromRGB(255, 0, 4),
		sheriff = Color3.fromRGB(0, 153, 255),
		innocent = Color3.fromRGB(0, 255, 8),
		gun = Color3.fromRGB(0, 153, 255),
		trap = Color3.fromHex("#A855F7"),
	},
}

ESP.gui = Instance.new("ScreenGui")
ESP.gui.Name = "MagmaEsp"
ESP.gui.IgnoreGuiInset = true
ESP.gui.ResetOnSpawn = false
ESP.gui.Parent = guiRoot

function ESP.add(adornee, options)
	if not adornee then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "HL"
	highlight.Adornee = adornee
	highlight.FillColor = options.color
	highlight.OutlineColor = options.color
	highlight.FillTransparency = options.fillT
	highlight.OutlineTransparency = options.outlineT
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = ESP.gui

	local group = ESP.groups[options.group]

	if not group then
		group = {}
		ESP.groups[options.group] = group
	end

	table.insert(group, highlight)

	if options.label then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "LBL"
		billboard.Adornee = options.labelAdornee or adornee
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.new(0, 140, 0, 16)
		billboard.StudsOffset = Vector3.new(0, options.labelAdornee and 2.2 or 2, 0)

		if options.maxDistance then
			billboard.MaxDistance = options.maxDistance
		end

		billboard.Parent = ESP.gui

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 11
		label.TextColor3 = options.color
		label.Text = options.label
		label.Parent = billboard

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 0.5
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label

		table.insert(group, billboard)
	end
end

function ESP.removeGroup(name)
	local group = ESP.groups[name]

	if not group then
		return
	end

	for _, item in ipairs(group) do
		pcall(function()
			item.Adornee = nil
			item:Destroy()
		end)
	end

	ESP.groups[name] = nil
end

function ESP.active()
	return ESP.outline or ESP.fill or ESP.names
end

function ESP.reveal(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" and descendant.Transparency >= 1 then
			tagPassthrough(descendant)

			if ESP.revealed[descendant] == nil then
				ESP.revealed[descendant] = descendant.Transparency
			end

			descendant.Transparency = 0.9
		end
	end
end

function ESP.unreveal()
	for part, transparency in next, ESP.revealed do
		pcall(function()
			if part.Parent then
				part.Transparency = transparency
			end
		end)
	end

	ESP.revealed = {}
end

function ESP.refreshPlayers()
	ESP.removeGroup("players")

	if not ESP.active() then
		return
	end

	local murderer = getMurderer()
	local sheriff = getSheriff()

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			ESP.reveal(player.Character)

			local color = ESP.colors.innocent

			if player == murderer then
				color = ESP.colors.murderer
			elseif player == sheriff then
				color = ESP.colors.sheriff
			end

			ESP.add(player.Character, {
				color = color,
				group = "players",
				fillT = ESP.fill and 0.75 or 1,
				outlineT = ESP.outline and 0.1 or 1,
				label = ESP.names and player.DisplayName or nil,
				labelAdornee = player.Character:FindFirstChild("Head"),
				maxDistance = 300,
			})
		end
	end
end

function ESP.refreshGun()
	ESP.removeGroup("gun")

	if not ESP.gun then
		return
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "GunDrop" and (descendant:IsA("BasePart") or descendant:IsA("Model")) then
			ESP.add(descendant, { color = ESP.colors.gun, group = "gun", label = "Gun", fillT = 0.5, outlineT = 0 })
		end
	end
end

local function isTrap(instance)
	return instance.Name == "Trap" and instance.Parent and (instance.Parent:IsA("Folder") or instance.Parent:IsA("Model"))
end

local function addTrap(instance)
	tagPassthrough(instance)

	pcall(function()
		instance.Transparency = 0
	end)

	ESP.add(instance, { color = ESP.colors.trap, group = "trap", label = "Trap", fillT = 0.5, outlineT = 0 })
end

function ESP.refreshTraps()
	ESP.removeGroup("trap")

	if not ESP.trap then
		return
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if isTrap(descendant) then
			addTrap(descendant)
		end
	end
end

function ESP.recolorSoon()
	if not ESP.active() then
		return
	end

	pcall(ESP.refreshPlayers)

	for _, delay in ipairs({ 0.1, 0.3, 0.6 }) do
		task.delay(delay, function()
			if alive and ESP.active() then
				pcall(ESP.refreshPlayers)
			end
		end)
	end
end

function ESP.sync()
	if ESP.active() then
		ESP.refreshPlayers()

		if not ESP.looping then
			ESP.looping = true

			task.spawn(function()
				while alive and ESP.looping do
					task.wait(1)

					if ESP.active() then
						pcall(ESP.refreshPlayers)
					end
				end
			end)
		end
	else
		ESP.removeGroup("players")
		ESP.looping = false
	end
end

local lastGunDropAlert = 0

track(Workspace.DescendantAdded:Connect(function(descendant)
	if ESP.trap and isTrap(descendant) then
		addTrap(descendant)
	end

	if descendant.Name == "Gun" and descendant:IsA("Tool") then
		if descendant.Parent and Players:GetPlayerFromCharacter(descendant.Parent) then
			ESP.recolorSoon()
		end
	end

	if descendant.Name == "GunDrop" and (descendant:IsA("BasePart") or descendant:IsA("Model")) then
		if ESP.gun then
			ESP.add(descendant, { color = ESP.colors.gun, group = "gun", label = "Gun", fillT = 0.5, outlineT = 0 })
		end

		if tick() - lastGunDropAlert > 3 then
			lastGunDropAlert = tick()
			playSfx("gun")
			notify("Gun Dropped!", "The sheriff died - the gun is on the floor.")
		end
	end
end))

track(Workspace.DescendantRemoving:Connect(function(descendant)
	if ESP.gun and descendant.Name == "GunDrop" then
		task.defer(ESP.refreshGun)
	end

	if ESP.trap and descendant.Name == "Trap" then
		task.defer(ESP.refreshTraps)
	end

	if descendant.Name == "GunDrop" then
		task.defer(ESP.recolorSoon)
	end
end))

pcall(function()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local gameplay = remotes and remotes:FindFirstChild("Gameplay")
	local changed = gameplay and gameplay:FindFirstChild("PlayerDataChanged")

	if changed and changed:IsA("RemoteEvent") then
		track(changed.OnClientEvent:Connect(function(data)
			roundData = data

			if ESP.active() then
				ESP.refreshPlayers()
			end
		end))
	end
end)

------------------------------------------------------------------ tracers

local Tracers = { lines = false, dist = false, arrows = false, parts = {}, roleAt = 0, murderer = nil, sheriff = nil, connection = nil }

function Tracers.any()
	return Tracers.lines or Tracers.dist or Tracers.arrows
end

function Tracers.colorOf(player)
	if player == Tracers.murderer then
		return ESP.colors.murderer
	elseif player == Tracers.sheriff then
		return ESP.colors.sheriff
	end

	return ESP.colors.innocent
end

function Tracers.slot(player)
	local existing = Tracers.parts[player]

	if existing and existing.line.Parent then
		return existing
	end

	local slot = {}

	slot.line = Instance.new("Frame")
	slot.line.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.line.BorderSizePixel = 0
	slot.line.Visible = false
	slot.line.ZIndex = 2
	slot.line.Parent = ESP.gui

	slot.label = Instance.new("TextLabel")
	slot.label.AnchorPoint = Vector2.new(0.5, 0)
	slot.label.BackgroundTransparency = 1
	slot.label.Size = UDim2.fromOffset(90, 14)
	slot.label.Font = Enum.Font.FredokaOne
	slot.label.TextSize = 11
	slot.label.Visible = false
	slot.label.ZIndex = 3
	slot.label.Parent = ESP.gui

	local labelStroke = Instance.new("UIStroke")
	labelStroke.Thickness = 0.5
	labelStroke.Color = Color3.new(0, 0, 0)
	labelStroke.Parent = slot.label

	slot.arrow = Instance.new("TextLabel")
	slot.arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.arrow.BackgroundTransparency = 1
	slot.arrow.Size = UDim2.fromOffset(28, 28)
	slot.arrow.Font = Enum.Font.SourceSansBold
	slot.arrow.TextSize = 24
	slot.arrow.Text = utf8.char(9650)
	slot.arrow.Visible = false
	slot.arrow.ZIndex = 3
	slot.arrow.Parent = ESP.gui

	local arrowStroke = Instance.new("UIStroke")
	arrowStroke.Thickness = 1
	arrowStroke.Color = Color3.new(0, 0, 0)
	arrowStroke.Parent = slot.arrow

	Tracers.parts[player] = slot
	return slot
end

function Tracers.drop(player)
	local slot = Tracers.parts[player]

	if not slot then
		return
	end

	Tracers.parts[player] = nil

	for _, instance in pairs(slot) do
		pcall(function()
			instance:Destroy()
		end)
	end
end

function Tracers.step()
	local camera = Workspace.CurrentCamera

	if not camera then
		return
	end

	local viewport = camera.ViewportSize

	if viewport.X < 1 or viewport.Y < 1 then
		return
	end

	local now = os.clock()

	if now - Tracers.roleAt > 0.5 then
		Tracers.roleAt = now
		Tracers.murderer = getMurderer()
		Tracers.sheriff = getSheriff()

		for player in pairs(Tracers.parts) do
			if player.Parent == nil then
				Tracers.drop(player)
			end
		end
	end

	local myRoot = rootOf(localPlayer)
	local bottomX = viewport.X * 0.5
	local bottomY = viewport.Y
	local centerX = viewport.X * 0.5
	local centerY = viewport.Y * 0.5
	local arrowRadius = math.min(viewport.X, viewport.Y) * 0.33
	local any = Tracers.any()

	for _, player in ipairs(Players:GetPlayers()) do
		local slot = Tracers.parts[player]
		local targetRoot = player ~= localPlayer and rootOf(player) or nil

		if any and targetRoot and isAlive(player) then
			slot = slot or Tracers.slot(player)
		elseif slot then
			slot.line.Visible = false
			slot.label.Visible = false
			slot.arrow.Visible = false
			slot = nil
		end

		if slot and slot.line.Parent then
			local color = Tracers.colorOf(player)
			local point, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
			local behind = point.Z <= 0
			local visible = onScreen and not behind

			if Tracers.lines and visible then
				local dx = point.X - bottomX
				local dy = point.Y - bottomY
				slot.line.BackgroundColor3 = color
				slot.line.Size = UDim2.fromOffset(2, math.sqrt(dx * dx + dy * dy))
				slot.line.Position = UDim2.fromOffset(bottomX + dx * 0.5, bottomY + dy * 0.5)
				slot.line.Rotation = math.deg(math.atan2(dy, dx)) - 90
				slot.line.Visible = true
			else
				slot.line.Visible = false
			end

			if Tracers.dist and visible then
				local origin = myRoot and myRoot.Position or camera.CFrame.Position
				local feet = camera:WorldToViewportPoint(targetRoot.Position - Vector3.new(0, 3.2, 0))
				slot.label.TextColor3 = color
				slot.label.Text = math.floor((targetRoot.Position - origin).Magnitude + 0.5) .. "m"
				slot.label.Position = UDim2.fromOffset(feet.X, feet.Y)
				slot.label.Visible = true
			else
				slot.label.Visible = false
			end

			if Tracers.arrows and not visible then
				local dx = point.X - centerX
				local dy = point.Y - centerY

				if behind then
					dx = -dx
					dy = -dy
				end

				local length = math.sqrt(dx * dx + dy * dy)

				if length < 1 then
					dx, dy, length = 0, -1, 1
				end

				slot.arrow.TextColor3 = color
				slot.arrow.Position = UDim2.fromOffset(centerX + dx / length * arrowRadius, centerY + dy / length * arrowRadius)
				slot.arrow.Rotation = math.deg(math.atan2(dy, dx)) + 90
				slot.arrow.Visible = true
			else
				slot.arrow.Visible = false
			end
		end
	end
end

function Tracers.sync()
	if Tracers.any() then
		if not Tracers.connection then
			Tracers.connection = RunService.RenderStepped:Connect(function()
				pcall(Tracers.step)
			end)
		end
	else
		Tracers.stop()
	end
end

function Tracers.stop()
	if Tracers.connection then
		pcall(function()
			Tracers.connection:Disconnect()
		end)

		Tracers.connection = nil
	end

	for player in pairs(Tracers.parts) do
		Tracers.drop(player)
	end
end

------------------------------------------------------------------ fling / teleport / server

local Fling = { active = false, all = false, spam = false, spamRunning = false, target = nil }

function Fling.run(target)
	if Fling.active then
		notify("Fling Active!", "Wait for the current fling to finish!", "error")
		return
	end

	if not target or not target.Character then
		notify("Error!", "Could not find that player!", "error")
		return
	end

	local targetHumanoid = target.Character:FindFirstChildOfClass("Humanoid")
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = humanoid and humanoid.RootPart

	if not targetHumanoid or not rootPart or targetHumanoid.Sit then
		return
	end

	local targetCharacter = target.Character
	local targetRoot = targetHumanoid.RootPart
	local head = targetCharacter:FindFirstChild("Head")
	local accessory = targetCharacter:FindFirstChildOfClass("Accessory")
	accessory = accessory and accessory:FindFirstChild("Handle")

	Fling.active = true

	local originalCFrame = rootPart.CFrame
	local originalDestroyHeight = Workspace.FallenPartsDestroyHeight
	local startHealth = humanoid.Health
	local camera = Workspace.CurrentCamera

	if head then
		camera.CameraSubject = head
	elseif accessory then
		camera.CameraSubject = accessory
	else
		camera.CameraSubject = targetHumanoid
	end

	local function placeAt(part, offset, angle)
		rootPart.CFrame = CFrame.new(part.Position) * offset * angle

		pcall(function()
			character:SetPrimaryPartCFrame(CFrame.new(part.Position) * offset * angle)
		end)

		rootPart.Velocity = Vector3.new(90000000, 900000000, 90000000)
		rootPart.RotVelocity = Vector3.new(900000000, 900000000, 900000000)
	end

	local function flingLoop(basePart)
		local startTime = tick()
		local spin = 0

		while rootPart and targetHumanoid and Fling.active do
			if basePart.Velocity.Magnitude < 50 then
				spin += 100
				local angle = CFrame.Angles(math.rad(spin), 0, 0)
				local velocityMove = targetHumanoid.MoveDirection * basePart.Velocity.Magnitude / 1.25

				placeAt(basePart, CFrame.new(0, 1.5, 0) + velocityMove, angle)
				task.wait()
				placeAt(basePart, CFrame.new(0, -1.5, 0) + velocityMove, angle)
				task.wait()
				placeAt(basePart, CFrame.new(2.25, 1.5, -2.25) + velocityMove, angle)
				task.wait()
				placeAt(basePart, CFrame.new(-2.25, -1.5, 2.25) + velocityMove, angle)
				task.wait()
				placeAt(basePart, CFrame.new(0, 1.5, 0) + targetHumanoid.MoveDirection, angle)
				task.wait()
				placeAt(basePart, CFrame.new(0, -1.5, 0) + targetHumanoid.MoveDirection, angle)
				task.wait()
			else
				local walk = targetHumanoid.WalkSpeed
				local quarter = math.pi / 2

				placeAt(basePart, CFrame.new(0, 1.5, walk), CFrame.Angles(quarter, 0, 0))
				task.wait()
				placeAt(basePart, CFrame.new(0, -1.5, -walk), CFrame.Angles(0, 0, 0))
				task.wait()
				placeAt(basePart, CFrame.new(0, 1.5, walk), CFrame.Angles(quarter, 0, 0))
				task.wait()
				placeAt(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(quarter, 0, 0))
				task.wait()
				placeAt(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
				task.wait()
				placeAt(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(-quarter, 0, 0))
				task.wait()
				placeAt(basePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
				task.wait()
			end

			if basePart.Velocity.Magnitude > 500
				or basePart.Parent ~= target.Character
				or target.Parent ~= Players
				or humanoid.Health <= 0
				or humanoid.Health < startHealth
				or targetHumanoid.Sit
				or tick() > startTime + 2
				or not Fling.active
			then
				break
			end
		end
	end

	Workspace.FallenPartsDestroyHeight = 0 / 0

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = "MagmaFlingBV"
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Parent = rootPart
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

	pcall(function()
		if targetRoot and head then
			if (targetRoot.CFrame.Position - head.CFrame.Position).Magnitude <= 5 then
				flingLoop(targetRoot)
			else
				flingLoop(head)
			end
		elseif targetRoot then
			flingLoop(targetRoot)
		elseif head then
			flingLoop(head)
		elseif accessory then
			flingLoop(accessory)
		end
	end)

	bodyVelocity:Destroy()
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
	camera.CameraSubject = humanoid

	pcall(function()
		for _ = 1, 50 do
			rootPart.CFrame = originalCFrame * CFrame.new(0, 0.5, 0)

			pcall(function()
				character:SetPrimaryPartCFrame(originalCFrame * CFrame.new(0, 0.5, 0))
			end)

			humanoid:ChangeState("GettingUp")

			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("BasePart") then
					child.Velocity = Vector3.zero
					child.RotVelocity = Vector3.zero
				end
			end

			task.wait()

			if (rootPart.Position - originalCFrame.Position).Magnitude < 25 then
				break
			end
		end
	end)

	Workspace.FallenPartsDestroyHeight = originalDestroyHeight
	Fling.active = false

	if humanoid.Health <= 0 then
		notify("Fling Backfired", target.Name .. " killed you mid-fling.")
	elseif humanoid.Health < startHealth then
		notify("Flinged!", "Flinged " .. target.Name .. " - took a hit, bailed early.")
	else
		notify("Flinged!", "Flinged " .. target.Name .. "!")
	end
end

function Fling.startSpam()
	if Fling.spamRunning then
		return
	end

	Fling.spamRunning = true

	task.spawn(function()
		while alive and Fling.spam do
			task.wait(0.5)

			pcall(function()
				if Fling.active or not Fling.target then
					return
				end

				local player = Players:FindFirstChild(Fling.target)

				if player and player ~= localPlayer and player.Character then
					Fling.run(player)
				end
			end)

			if Fling.active then
				while Fling.active and Fling.spam do
					task.wait(0.2)
				end

				task.wait(1)
			end
		end

		Fling.spamRunning = false
	end)
end

function Fling.runAll()
	if Fling.all then
		Fling.all = false
		notify("Fling All Stopped!", "Cancelled.")
		return
	end

	local targets = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			targets[#targets + 1] = player
		end
	end

	if #targets == 0 then
		notify("Fling All", "Nobody to fling!", "error")
		return
	end

	Fling.all = true

	task.spawn(function()
		notify("Fling All", "Flinging " .. #targets .. " players...")
		local count = 0

		for _, player in ipairs(targets) do
			if not Fling.all then
				break
			end

			if player.Parent and player.Character then
				pcall(Fling.run, player)
				local started = tick()

				while Fling.active and Fling.all and tick() - started < 12 do
					task.wait(0.1)
				end

				count += 1
			end
		end

		if Fling.all then
			notify("Fling All Done!", "Flung " .. count .. " players.")
		end

		Fling.all = false
	end)
end

local function teleportTo(player, label)
	local character = player and player.Character

	if not character or not character:FindFirstChild("HumanoidRootPart") then
		notify("Error!", "No " .. label .. " found!", "error")
		return
	end

	local myRoot = rootOf(localPlayer)

	if not myRoot then
		return
	end

	myRoot.Velocity = Vector3.zero
	myRoot.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
	notify("Teleported!", "Teleported to " .. label)
end

local Server = { hopThread = nil, hopping = false, MIN_PLAYERS = 2, GRACE = 15, RETRY = 60, CONFIRM = 6 }

function Server.hop()
	notify("Server Hop", "Teleporting to a new server...")
	task.wait(0.5)

	local ok, result = pcall(function()
		TeleportService:Teleport(placeId)
	end)

	if not ok then
		notify("Error!", "Failed to hop: " .. tostring(result), "error")
	end
end

function Server.smallest()
	notify("Smallest Server", "Finding the emptiest server...")

	local servers = {}
	local cursor = ""

	for _ = 1, 5 do
		local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"

		if cursor ~= "" then
			url ..= "&cursor=" .. cursor
		end

		local page = httpJson(url)

		if not page or not page.data then
			break
		end

		for _, server in ipairs(page.data) do
			if server.id ~= jobId and server.playing and server.maxPlayers and server.playing < server.maxPlayers then
				table.insert(servers, server)
			end
		end

		cursor = page.nextPageCursor or ""

		if cursor == "" then
			break
		end
	end

	if #servers == 0 then
		notify("No Servers!", "No joinable servers found. Trying random hop...", "error")
		task.wait(1)
		pcall(function()
			TeleportService:Teleport(placeId)
		end)
		return
	end

	table.sort(servers, function(a, b)
		return a.playing < b.playing
	end)

	notify("Joining!", "Joining server with " .. servers[1].playing .. " players...")
	task.wait(0.5)

	pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, servers[1].id)
	end)
end

function Server.populatedHop()
	if Server.hopping then
		return false
	end

	Server.hopping = true
	notify("Server Empty", "Under " .. Server.MIN_PLAYERS .. " players here - hopping...")
	task.wait(0.5)

	if pcall(function()
		TeleportService:Teleport(placeId)
	end) then
		task.wait(Server.CONFIRM)
	end

	notify("Matchmaking Refused", "Picking from the server list...", "error")

	local best = nil
	local cursor = ""

	for _ = 1, 4 do
		local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Desc&limit=100"

		if cursor ~= "" then
			url ..= "&cursor=" .. cursor
		end

		local page = httpJson(url)

		if not page or not page.data then
			break
		end

		for _, server in ipairs(page.data) do
			if server.id ~= jobId and server.playing and server.maxPlayers and server.playing < server.maxPlayers then
				if not best or server.playing > best.playing then
					best = server
				end
			end
		end

		cursor = page.nextPageCursor or ""

		if cursor == "" then
			break
		end
	end

	if best then
		notify("Hopping", "Joining a server with " .. best.playing .. " players...")
		task.wait(0.5)

		if pcall(function()
			TeleportService:TeleportToPlaceInstance(placeId, best.id)
		end) then
			task.wait(Server.CONFIRM)
		end
	end

	Server.hopping = false
	notify("Hop Failed", "The server would not let go. Trying again in a minute.", "error")
	return false
end

function Server.stopWatch()
	if Server.hopThread then
		pcall(task.cancel, Server.hopThread)
		Server.hopThread = nil
	end
end

function Server.startWatch(enabledGetter)
	Server.stopWatch()

	Server.hopThread = task.spawn(function()
		local waited = 0

		while alive do
			task.wait(3)

			if not enabledGetter() or #Players:GetPlayers() >= Server.MIN_PLAYERS then
				waited = 0
			else
				waited += 3

				if waited >= Server.GRACE then
					pcall(Server.populatedHop)
					task.wait(Server.RETRY)
					waited = 0
				end
			end
		end
	end)
end

------------------------------------------------------------------ player movement

local Move = {
	walkSpeed = 16,
	jumpPower = 50,
	noclip = false,
	fly = false,
	flySpeed = 50,
	infJump = false,
	antiFling = false,
	clipParts = {},
}

local function restoreCollision(parts)
	for part in next, parts do
		pcall(function()
			if part.Parent then
				part.CanCollide = true
			end
		end)
	end

	table.clear(parts)
end

function Move.setWalkSpeed(value)
	Move.walkSpeed = value
	local humanoid = getHumanoid()

	if humanoid then
		humanoid.WalkSpeed = value
	end
end

function Move.setJumpPower(value)
	Move.jumpPower = value
	local humanoid = getHumanoid()

	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = value
	end
end

function Move.startNoclip()
	if Move.noclipConnection then
		return
	end

	Move.noclipConnection = RunService.Stepped:Connect(function()
		if not Move.noclip then
			return
		end

		local character = localPlayer.Character

		if character then
			for _, descendant in ipairs(character:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.CanCollide then
					Move.clipParts[descendant] = true
					descendant.CanCollide = false
				end
			end
		end
	end)
end

function Move.stopNoclip()
	if Move.noclipConnection then
		Move.noclipConnection:Disconnect()
		Move.noclipConnection = nil
	end

	restoreCollision(Move.clipParts)
end

function Move.startFly()
	if Move.flyConnection then
		return
	end

	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not rootPart or not humanoid then
		return
	end

	Move.flyVelocity = Instance.new("BodyVelocity")
	Move.flyVelocity.Name = "MagmaFlyVelocity"
	Move.flyVelocity.Velocity = Vector3.zero
	Move.flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	Move.flyVelocity.Parent = rootPart

	Move.flyGyro = Instance.new("BodyGyro")
	Move.flyGyro.Name = "MagmaFlyGyro"
	Move.flyGyro.P = 90000
	Move.flyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	Move.flyGyro.CFrame = rootPart.CFrame
	Move.flyGyro.Parent = rootPart
	humanoid.PlatformStand = true

	Move.flyConnection = RunService.Heartbeat:Connect(function()
		pcall(function()
			if not Move.fly then
				return
			end

			local camera = Workspace.CurrentCamera
			local direction = Vector3.zero
			Move.flyGyro.CFrame = camera.CFrame

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				direction += camera.CFrame.LookVector
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				direction -= camera.CFrame.LookVector
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				direction -= camera.CFrame.RightVector
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				direction += camera.CFrame.RightVector
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				direction += Vector3.new(0, 1, 0)
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				direction -= Vector3.new(0, 1, 0)
			end

			Move.flyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * Move.flySpeed or Vector3.zero
		end)
	end)
end

function Move.stopFly()
	if Move.flyConnection then
		Move.flyConnection:Disconnect()
		Move.flyConnection = nil
	end

	if Move.flyVelocity then
		Move.flyVelocity:Destroy()
		Move.flyVelocity = nil
	end

	if Move.flyGyro then
		Move.flyGyro:Destroy()
		Move.flyGyro = nil
	end

	local humanoid = getHumanoid()

	if humanoid then
		humanoid.PlatformStand = false
	end
end

function Move.startInfJump()
	if Move.jumpConnection then
		return
	end

	local last = 0

	Move.jumpConnection = UserInputService.JumpRequest:Connect(function()
		if not Move.infJump then
			return
		end

		local now = tick()

		if now - last < 0.15 then
			return
		end

		last = now
		local humanoid = getHumanoid()

		if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
end

function Move.stopInfJump()
	if Move.jumpConnection then
		Move.jumpConnection:Disconnect()
		Move.jumpConnection = nil
	end
end

function Move.startAntiFling()
	if Move.antiFlingConnection then
		return
	end

	Move.antiFlingConnection = RunService.Heartbeat:Connect(function()
		if not Move.antiFling then
			return
		end

		pcall(function()
			local myRoot = rootOf(localPlayer)

			if not myRoot then
				return
			end

			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= localPlayer and player.Character then
					for _, descendant in ipairs(player.Character:GetDescendants()) do
						if descendant:IsA("BasePart") and not descendant.Anchored and descendant.Velocity.Magnitude > 200 then
							if (descendant.Position - myRoot.Position).Magnitude < 30 then
								descendant.Velocity = Vector3.zero
								descendant.RotVelocity = Vector3.zero
								descendant.Anchored = true

								task.delay(0.3, function()
									if descendant and descendant.Parent then
										descendant.Anchored = false
									end
								end)
							end
						end
					end
				end
			end
		end)
	end)
end

function Move.stopAntiFling()
	if Move.antiFlingConnection then
		Move.antiFlingConnection:Disconnect()
		Move.antiFlingConnection = nil
	end
end

track(localPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	task.wait(0.5)

	if Move.walkSpeed ~= 16 then
		humanoid.WalkSpeed = Move.walkSpeed
	end

	if Move.jumpPower ~= 50 then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Move.jumpPower
	end

	if Move.fly then
		pcall(Move.stopFly)
		task.wait(0.2)
		pcall(Move.startFly)
	end

	if Move.noclip then
		pcall(Move.stopNoclip)
		pcall(Move.startNoclip)
	end
end))

------------------------------------------------------------------ HUD buttons

local HUD = {
	parts = {},
	positions = {},
	locked = false,
	scale = IS_MOBILE and 0.7 or 1,
	defs = {},
}

local TILE = IS_MOBILE and 72 or 84
local TILE_GAP = 10
local COOLDOWN_GREY = Color3.fromRGB(72, 72, 80)

local HUD_ROWS = {
	{ "Shoot", "Grab", "Bomb", "Throw", "WallHop" },
	{ "KillAll", "KillSheriff", "Fly", "Noclip", "Xray" },
}

local HUD_ICONS = {
	crosshair = "rbxassetid://134242818164054",
	hand = "rbxassetid://130703864968637",
	sword = "rbxassetid://124448418211665",
	bomb = "http://www.roblox.com/Thumbs/Asset.ashx?format=png&width=250&height=250&assetId=342187115",
	target = "rbxassetid://87563802520297",
	climb = "rbxassetid://100467452364672",
	skull = "rbxassetid://137726256442333",
	plane = "rbxassetid://126985561580989",
	ghost = "rbxassetid://113822048130017",
	badge = "rbxassetid://116620312917084",
	xray = "rbxassetid://340313896",
}

-- Sprite sheet crops: { x, y, size }
local HUD_ART = { Xray = { 165, 85, 250 }, Bomb = { 8, 24, 170 } }

local function lighten(color, amount)
	return Color3.new(color.R + (1 - color.R) * amount, color.G + (1 - color.G) * amount, color.B + (1 - color.B) * amount)
end

function HUD.defaultPosition(name)
	for rowIndex, row in ipairs(HUD_ROWS) do
		for index, entry in ipairs(row) do
			if entry == name then
				return UDim2.new(0.5, (index - (#row + 1) / 2) * (TILE + TILE_GAP) * HUD.scale, 0.25, (rowIndex - 1) * (TILE + TILE_GAP) * HUD.scale)
			end
		end
	end

	return UDim2.fromScale(0.5, 0.25)
end

function HUD.relayout()
	for name, part in next, HUD.parts do
		if not HUD.positions[name] then
			part.button.Position = HUD.defaultPosition(name)
		end
	end
end

function HUD.paint(part)
	local active = part.active
	local onCooldown = part.cooldownUntil ~= nil

	TweenService:Create(part.stroke, TweenInfo.new(0.15), {
		Color = onCooldown and COOLDOWN_GREY or (active and part.accent or Color3.new(1, 1, 1)),
		Transparency = onCooldown and 0.5 or (active and 0.35 or 0.88),
	}):Play()

	if not part.art then
		TweenService:Create(part.icon, TweenInfo.new(0.15), {
			ImageColor3 = onCooldown and Color3.fromRGB(124, 124, 134) or lighten(part.accent, active and 0.6 or 0.25),
		}):Play()
	end

	TweenService:Create(part.label, TweenInfo.new(0.15), {
		TextColor3 = onCooldown and Color3.fromRGB(112, 112, 124) or (active and Color3.fromRGB(240, 240, 246) or Color3.fromRGB(146, 146, 158)),
	}):Play()

	if not onCooldown then
		part.fill.BackgroundColor3 = part.accent
		part.fill.Size = UDim2.fromScale(active and 1 or 0, 1)
	end
end

function HUD.setActive(name, active)
	local part = HUD.parts[name]

	if part then
		part.active = active
		HUD.paint(part)
	end
end

function HUD.cooldown(name, seconds, text)
	local part = HUD.parts[name]

	if not part then
		return
	end

	part.cooldownUntil = os.clock() + seconds
	part.fill.BackgroundColor3 = COOLDOWN_GREY
	part.fill.Size = UDim2.fromScale(1, 1)
	TweenService:Create(part.fill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	HUD.paint(part)

	if part.cooldownThread then
		return
	end

	local head = text:match("^[^\n]+") or text

	part.cooldownThread = task.spawn(function()
		while part.cooldownUntil and part.cooldownUntil - os.clock() > 0 and part.button.Parent do
			part.label.Text = head .. "\n" .. string.format("%.1fs", part.cooldownUntil - os.clock())
			task.wait(0.05)
		end

		part.cooldownUntil = nil
		part.cooldownThread = nil

		if part.button.Parent then
			part.label.Text = text
			HUD.paint(part)
		end
	end)
end

function HUD.clearCooldown(name)
	local part = HUD.parts[name]

	if part then
		part.cooldownUntil = nil
	end
end

function HUD.create(name)
	local def = HUD.defs[name]

	if HUD.parts[name] or not def then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MagmaHud" .. name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = guiRoot

	local saved = HUD.positions[name]
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Size = UDim2.fromOffset(TILE, TILE)
	button.Position = saved and UDim2.new(saved[1], saved[2], saved[3], saved[4]) or HUD.defaultPosition(name)
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(10, 10, 13)
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.Parent = gui

	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 20)

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = HUD.scale
	uiScale.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.88
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local art = HUD_ART[name]
	local iconSize = art and 28 or 24

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.5, 0, 0, 22)
	icon.Size = UDim2.fromOffset(iconSize, iconSize)
	icon.BackgroundTransparency = 1
	icon.Image = HUD_ICONS[def.icon] or ""
	icon.ImageColor3 = art and Color3.new(1, 1, 1) or lighten(def.accent, 0.25)
	icon.ZIndex = 3
	icon.Parent = button

	if art then
		icon.ImageRectOffset = Vector2.new(art[1], art[2])
		icon.ImageRectSize = Vector2.new(art[3], art[3])
	end

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -13)
	label.Size = UDim2.new(1, -6, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = select(2, def.text:gsub("\n", "")) >= 2 and (IS_MOBILE and 8 or 9) or (IS_MOBILE and 9 or 10)
	label.LineHeight = 1.05
	label.TextWrapped = true
	label.Text = def.text
	label.TextColor3 = Color3.fromRGB(146, 146, 158)
	label.ZIndex = 4
	label.Parent = button

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -6)
	track.Size = UDim2.new(1, -26, 0, 4)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BackgroundTransparency = 0.86
	track.BorderSizePixel = 0
	track.ZIndex = 4
	track.Parent = button
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = def.accent
	fill.BorderSizePixel = 0
	fill.ZIndex = 5
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local part = {
		gui = gui,
		button = button,
		stroke = stroke,
		icon = icon,
		label = label,
		fill = fill,
		accent = def.accent,
		art = art ~= nil,
		active = false,
		scale = uiScale,
		conns = {},
	}

	local dragging = false
	local dragMoved = false
	local dragInput = nil
	local startPosition = nil
	local startMouse = nil
	local lastClick = 0

	table.insert(part.conns, button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragMoved = false
			dragInput = input
			startPosition = button.Position
			startMouse = input.Position
		end
	end))

	table.insert(part.conns, UserInputService.InputChanged:Connect(function(input)
		if not dragging or HUD.locked or not button.Parent then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= dragInput then
			return
		end

		local delta = input.Position - startMouse

		if not dragMoved then
			if math.abs(delta.X) + math.abs(delta.Y) < 6 then
				return
			end

			dragMoved = true
		end

		button.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
	end))

	table.insert(part.conns, UserInputService.InputEnded:Connect(function(input)
		if not dragging or (input ~= dragInput and input.UserInputType ~= Enum.UserInputType.MouseButton1) then
			return
		end

		dragging = false

		if dragMoved then
			local position = button.Position
			HUD.positions[name] = { position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset }
		end

		task.delay(0.05, function()
			dragMoved = false
		end)
	end))

	table.insert(part.conns, button.Activated:Connect(function()
		if dragMoved then
			return
		end

		local now = os.clock()

		if now - lastClick < 0.2 then
			return
		end

		lastClick = now
		playSfx("click")
		TweenService:Create(uiScale, TweenInfo.new(0.06), { Scale = HUD.scale * 0.93 }):Play()

		task.delay(0.08, function()
			if uiScale.Parent then
				TweenService:Create(uiScale, TweenInfo.new(0.16), { Scale = HUD.scale }):Play()
			end
		end)

		task.spawn(def.action)
	end))

	HUD.parts[name] = part
	return part
end

function HUD.destroy(name)
	local part = HUD.parts[name]

	if not part then
		return
	end

	disconnectAll(part.conns)
	part.gui:Destroy()
	HUD.parts[name] = nil
end

function HUD.destroyAll()
	for name in pairs(HUD.parts) do
		HUD.destroy(name)
	end
end

function HUD.capture()
	local data = {}

	for name, part in next, HUD.parts do
		if part.button.Parent then
			local position = part.button.Position
			data[name] = { position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset }
		end
	end

	for name, saved in next, HUD.positions do
		data[name] = data[name] or saved
	end

	return data
end

------------------------------------------------------------------ combat

local Combat = {
	wallCheck = false,
	wallbang = false,
	gunCooldown = false,
	knifeCooldown = false,
	lastBomb = 0,
	wallHopBusy = false,
	lastWallHop = 0,
	velocity = {},
	aimLead = 0.16,
}

local COOLDOWN = { Shoot = 3.2, Throw = 2, Bomb = 22 }

function Combat.hasLineOfSight(targetCharacter, fromPart)
	if not targetCharacter or not fromPart then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { localPlayer.Character }
	params.RespectCanCollide = true

	local points = {}

	for _, name in ipairs({ "HumanoidRootPart", "Head", "UpperTorso", "Torso", "LeftFoot", "RightFoot" }) do
		local part = targetCharacter:FindFirstChild(name)

		if part then
			table.insert(points, part.Position)
		end
	end

	if #points == 0 and targetCharacter.PrimaryPart then
		table.insert(points, targetCharacter.PrimaryPart.Position)
	end

	for _, point in ipairs(points) do
		local hit = Workspace:Raycast(fromPart.Position, point - fromPart.Position, params)

		if not hit then
			return true
		end

		if hit.Instance:IsDescendantOf(targetCharacter) or hit.Instance.Transparency > 0.5 or hit.Instance.CanCollide == false then
			return true
		end
	end

	return false
end

function Combat.startVelocityTracker()
	if Combat.velocityConnection then
		return
	end

	Combat.velocityConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()

		for _, player in ipairs(Players:GetPlayers()) do
			local root = rootOf(player)

			if not root then
				Combat.velocity[player] = nil
			else
				local entry = Combat.velocity[player]

				if not entry then
					Combat.velocity[player] = { position = root.Position, time = now, velocity = Vector3.zero }
				elseif now - entry.time >= 0.03 then
					entry.velocity = (root.Position - entry.position) / (now - entry.time)
					entry.position = root.Position
					entry.time = now
				end
			end
		end
	end)
end

local Predict = {
	value = { X = 0.143, Y = 0.143, Z = 0.143 },
	MAX_OFFSET = 40,
	BULLET_SPEED = 600,
}

function Predict.ping()
	local ok, ping = pcall(function()
		return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
	end)

	return (ok and type(ping) == "number" and ping > 0 and ping < 1) and ping or 0.04
end

function Predict.velocity(player, part)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local velocity = part.AssemblyLinearVelocity or Vector3.zero

	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		local walking = humanoid.MoveDirection.Unit * humanoid.WalkSpeed
		velocity = Vector3.new(walking.X, velocity.Y, walking.Z)
	elseif Vector3.new(velocity.X, 0, velocity.Z).Magnitude < 0.5 then
		local entry = Combat.velocity[player]

		if entry and entry.velocity.Magnitude >= 0.5 then
			velocity = entry.velocity
		end
	end

	return velocity
end

-- One prediction for silent aim, triggerbot and Shoot Murderer: position + velocity * (X, Y, Z). All zero turns it off.
function Predict.position(player, part)
	local scale = Predict.value
	local velocity = Predict.velocity(player, part)

	if velocity.Magnitude < 0.5 then
		return part.Position
	end

	local offset = Vector3.new(velocity.X * scale.X, velocity.Y * scale.Y, velocity.Z * scale.Z)

	if offset.Magnitude > Predict.MAX_OFFSET then
		offset = offset.Unit * Predict.MAX_OFFSET
	end

	return part.Position + offset
end

function Predict.setMarker(on)
	if on then
		if Predict.markerConnection then
			return
		end

		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(9, 9)
		dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		dot.BorderSizePixel = 0
		dot.Visible = false
		dot.ZIndex = 5
		dot.Parent = ESP.gui
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 60, 80)
		stroke.Thickness = 2
		stroke.Parent = dot

		Predict.dot = dot

		Predict.markerConnection = RunService.RenderStepped:Connect(function()
			local murderer = getMurderer()
			local root = murderer and murderer ~= localPlayer and rootOf(murderer)
			local camera = Workspace.CurrentCamera

			if not root or not isAlive(murderer) or not camera then
				dot.Visible = false
				return
			end

			local point = camera:WorldToViewportPoint(Predict.position(murderer, root))
			dot.Visible = point.Z > 0
			dot.Position = UDim2.fromOffset(point.X, point.Y)
		end)
	else
		if Predict.markerConnection then
			Predict.markerConnection:Disconnect()
			Predict.markerConnection = nil
		end

		if Predict.dot then
			Predict.dot:Destroy()
			Predict.dot = nil
		end
	end
end

function Combat.aimAt(player, part)
	return Predict.position(player, part)
end

function Combat.predict(player, speed, factor)
	local character = player.Character

	if not character then
		return nil
	end

	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")

	if not torso then
		return nil
	end

	local position = torso.Position
	local velocity = torso.AssemblyLinearVelocity or Vector3.zero
	local mine = localPlayer.Character
	local myTorso = mine and (mine:FindFirstChild("UpperTorso") or mine:FindFirstChild("HumanoidRootPart"))

	if not myTorso then
		return position
	end

	local distance = (position - myTorso.Position).Magnitude

	if distance < 1 then
		return position
	end

	return position + velocity * math.min(distance / speed * (factor or 1), 0.5)
end

function Combat.nearestPlayer()
	local myRoot = rootOf(localPlayer)

	if not myRoot then
		return nil
	end

	local best, bestDistance = nil, math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local root = player ~= localPlayer and rootOf(player)

		if root then
			local distance = (myRoot.Position - root.Position).Magnitude

			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end

	return best
end

function Combat.mouseAimPoint()
	local camera = Workspace.CurrentCamera

	if not camera then
		return nil
	end

	local ok, result = pcall(function()
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { localPlayer.Character }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		return hit and hit.Position or ray.Origin + ray.Direction * 300
	end)

	return ok and result or nil
end

function Combat.getTool(name)
	local character = localPlayer.Character
	local backpack = localPlayer:FindFirstChild("Backpack")
	return (character and character:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
end

function Combat.equip(name)
	local character = localPlayer.Character

	if not character then
		return nil
	end

	local tool = character:FindFirstChild(name)

	if tool then
		return tool
	end

	local backpack = localPlayer:FindFirstChild("Backpack")
	local stored = backpack and backpack:FindFirstChild(name)
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if stored and humanoid then
		humanoid:EquipTool(stored)
		task.wait(0.1)
		return character:FindFirstChild(name)
	end

	return nil
end

function Combat.throwCooldown(knife)
	local speed = knife and knife:GetAttribute("ThrowSpeed")

	if type(speed) == "number" and speed > 0 then
		return 2 * speed
	end

	return COOLDOWN.Throw
end

function Combat.shootMurderer()
	if Combat.gunCooldown then
		return
	end

	Combat.gunCooldown = true

	local function release(delay)
		task.delay(delay, function()
			Combat.gunCooldown = false
		end)
	end

	if getSheriff() ~= localPlayer then
		release(0.5)
		notify("Not Sheriff!", "You don't have the gun.", "error")
		return
	end

	local murderer = getMurderer()

	if not murderer or not murderer.Character then
		release(0.5)
		notify("Error!", "No murderer this round!", "error")
		return
	end

	local myRoot = rootOf(localPlayer)
	local murdererRoot = rootOf(murderer)

	if not myRoot or not murdererRoot then
		release(0.5)
		return
	end

	if Combat.wallCheck and not Combat.wallbang then
		local origin = localPlayer.Character:FindFirstChild("RightHand") or myRoot

		if not Combat.hasLineOfSight(murderer.Character, origin) then
			release(0.5)
			notify("Wall Detected!", "Murderer is behind a wall. Turn off Wall Check to shoot through it.", "error")
			return
		end
	end

	local gun = Combat.equip("Gun")
	local shoot = gun and gun:FindFirstChild("Shoot")

	if not shoot or not shoot:IsA("RemoteEvent") then
		release(0.5)
		return
	end

	if (myRoot.Position - murdererRoot.Position).Magnitude > 300 then
		release(0.5)
		notify("Too Far!", "The gun only reaches 300 studs.", "error")
		return
	end

	local attachment = myRoot:FindFirstChild("GunRaycastAttachment")
	local origin = attachment and attachment.WorldCFrame or CFrame.new(myRoot.Position)
	local aim = Combat.aimAt(murderer, murdererRoot)

	if Combat.wallbang then
		shoot:FireServer(CFrame.new(aim + Vector3.new(0, 1.5, 0)), CFrame.new(aim))
	else
		shoot:FireServer(origin, CFrame.new(aim))
	end

	release(0.35)
end

function Combat.throwKnife()
	if Combat.knifeCooldown then
		return
	end

	Combat.knifeCooldown = true

	local function release(delay)
		task.delay(delay, function()
			Combat.knifeCooldown = false
		end)
	end

	if getMurderer() ~= localPlayer then
		notify("Not Murderer!", "You don't have the knife.", "error")
		release(0.5)
		return
	end

	local target = Combat.nearestPlayer()

	if not target or not target.Character then
		notify("Error!", "No one nearby to throw at.", "error")
		release(0.5)
		return
	end

	local hand = localPlayer.Character:FindFirstChild("RightHand") or localPlayer.Character:FindFirstChild("HumanoidRootPart")

	if not hand then
		release(0.5)
		return
	end

	if Combat.wallCheck and not Combat.hasLineOfSight(target.Character, hand) then
		notify("Wall Detected!", target.Name .. " is behind a wall.", "error")
		release(0.5)
		return
	end

	local knife = Combat.equip("Knife")
	local aim = knife and Combat.predict(target, 600, 0.95)

	if not knife or not aim then
		release(0.5)
		return
	end

	local throw = knife:FindFirstChild("Throw") or (knife:FindFirstChild("Events") and knife.Events:FindFirstChild("KnifeThrown"))

	if throw and throw:IsA("RemoteEvent") then
		throw:FireServer(CFrame.new(hand.Position), CFrame.new(aim))

		pcall(function()
			local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			local animation = knife:FindFirstChild("ThrowKnife", true)

			if animator and animation then
				animator:LoadAnimation(animation):Play(0.1, 6, 1)
			end
		end)

		local cooldown = Combat.throwCooldown(knife)
		HUD.cooldown("Throw", cooldown, "THROW\nKNIFE")
		release(cooldown)
	else
		release(0.5)
	end
end

function Combat.findGunDrop()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "GunDrop" and descendant.Parent then
			return descendant
		end
	end

	return nil
end

function Combat.pickupGun()
	local drop = Combat.findGunDrop()

	if not drop then
		return false, "nodrop"
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return false, "nochar"
	end

	local touch = nil

	if drop:IsA("BasePart") and drop:FindFirstChild("TouchInterest") then
		touch = drop
	end

	if not touch then
		for _, descendant in ipairs(drop:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:FindFirstChild("TouchInterest") then
				touch = descendant
				break
			end
		end
	end

	if not touch then
		if drop:IsA("BasePart") then
			touch = drop
		else
			touch = drop:FindFirstChildWhichIsA("BasePart", true)
		end
	end

	if not touch then
		return false, "notouch"
	end

	if not firetouchinterest then
		return false, "noapi"
	end

	for _ = 1, 5 do
		pcall(function()
			firetouchinterest(root, touch, 0)
			firetouchinterest(root, touch, 1)
		end)

		task.wait(0.05)

		if Combat.getTool("Gun") then
			return true
		end
	end

	return false, "refused"
end

function Combat.grabGun()
	local ok, reason = Combat.pickupGun()

	if ok then
		notify("Gun Grabbed!", "Got the gun!")
		return
	end

	if reason == "nochar" then
		notify("No Character", "Nothing to grab with right now.", "error")
	elseif reason == "noapi" then
		notify("Unsupported", "Your executor has no firetouchinterest.", "error")
	elseif not findMap() then
		notify("Not In A Round", "The round is over, so the gun can't be picked up.", "error")
	elseif reason == "nodrop" then
		notify("No Gun Found!", "No gun on the ground right now.", "error")
	else
		notify("Couldn't Grab It", "Found the gun but the pickup didn't land - move closer and try again.", "error")
	end
end

function Combat.startAutoGrab()
	if Combat.grabThread then
		return
	end

	Combat.grabThread = task.spawn(function()
		while alive do
			task.wait(0.12)

			if not Combat.getTool("Gun") then
				pcall(Combat.pickupGun)
			end
		end
	end)
end

function Combat.stopAutoGrab()
	if Combat.grabThread then
		pcall(task.cancel, Combat.grabThread)
		Combat.grabThread = nil
	end
end

function Combat.bombJump()
	local now = tick()

	if now - Combat.lastBomb < COOLDOWN.Bomb then
		notify("Cooldown", string.format("Bomb jump on cooldown for %.1fs", COOLDOWN.Bomb - (now - Combat.lastBomb)), "error")
		return
	end

	pcall(function()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root then
			return
		end

		local previous = character:FindFirstChildOfClass("Tool")
		local bomb = character:FindFirstChild("FakeBomb")

		if not bomb then
			local backpack = localPlayer:FindFirstChild("Backpack")
			local stored = backpack and backpack:FindFirstChild("FakeBomb")

			if stored then
				humanoid:EquipTool(stored)
				task.wait(0.1)
				bomb = character:FindFirstChild("FakeBomb")
			end
		end

		if not bomb then
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local extras = remotes and remotes:FindFirstChild("Extras")
			local toy = extras and extras:FindFirstChild("ReplicateToy")

			if toy then
				toy:InvokeServer("FakeBomb")
				task.wait(0.15)
				bomb = character:FindFirstChild("FakeBomb")

				if not bomb then
					local backpack = localPlayer:FindFirstChild("Backpack")

					if backpack and backpack:FindFirstChild("FakeBomb") then
						humanoid:EquipTool(backpack.FakeBomb)
						task.wait(0.1)
						bomb = character:FindFirstChild("FakeBomb")
					end
				end
			end
		end

		if not bomb then
			notify("No Bomb", "Couldn't get the FakeBomb toy.", "error")
			return
		end

		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		task.wait(0.05)

		local remote = bomb:FindFirstChild("Remote")

		if remote then
			local position = root.Position
			remote:FireServer(CFrame.new(position.X, position.Y - 3, position.Z), 50)
			Combat.lastBomb = tick()
			HUD.cooldown("Bomb", COOLDOWN.Bomb, "BOMB\nJUMP")
		end

		task.wait(0.1)
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		task.wait(0.1)
		humanoid:UnequipTools()

		if previous and previous ~= bomb and previous.Name ~= "FakeBomb" then
			task.wait(0.1)

			if previous.Parent then
				pcall(function()
					humanoid:EquipTool(previous)
				end)
			end
		end
	end)
end

function Combat.syncBombCooldown()
	local function watch(container)
		if not container then
			return
		end

		local function hook(tool)
			if tool.Name == "FakeBomb" and tool:IsA("Tool") then
				track(tool.Activated:Connect(function()
					if tick() - Combat.lastBomb < COOLDOWN.Bomb then
						return
					end

					Combat.lastBomb = tick()
					HUD.cooldown("Bomb", COOLDOWN.Bomb, "BOMB\nJUMP")
				end))
			end
		end

		for _, child in ipairs(container:GetChildren()) do
			hook(child)
		end

		track(container.ChildAdded:Connect(hook))
	end

	watch(localPlayer:FindFirstChild("Backpack"))
	watch(localPlayer.Character)
end

function Combat.wallHop()
	if Combat.wallHopBusy or os.clock() - Combat.lastWallHop < 0.2 then
		return
	end

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local function findWall()
		for _, direction in ipairs({ root.CFrame.LookVector, root.CFrame.RightVector, -root.CFrame.RightVector }) do
			local hit = Workspace:Raycast(root.Position, direction * 4, params)

			if hit and hit.Instance and hit.Instance.CanCollide then
				return hit
			end
		end

		return nil
	end

	local wall = findWall()

	if not wall then
		notify("No wall", "Stand next to a wall first.", "error")
		return
	end

	Combat.wallHopBusy = true

	task.spawn(function()
		local function finish()
			Combat.wallHopBusy = false
			Combat.lastWallHop = os.clock()
		end

		local normal = -wall.Normal
		local flat = Vector3.new(normal.X, 0, normal.Z)

		if flat.Magnitude < 0.05 then
			finish()
			return
		end

		local push = flat.Unit

		local function kick()
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.new(push.X * 14, root.AssemblyLinearVelocity.Y, push.Z * 14)
			end)

			humanoid.Jump = true

			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end)
		end

		kick()
		task.wait(0.12)

		-- Flick the character toward the wall for a moment to climb it.
		local lock = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

		if lock then
			RunService:BindToRenderStep("MagmaWallFlick", Enum.RenderPriority.Camera.Value + 1, function()
				root.CFrame = CFrame.lookAt(root.Position, root.Position + push) * CFrame.Angles(0, math.rad(60), 0)
			end)

			task.wait(0.08)
			pcall(function()
				RunService:UnbindFromRenderStep("MagmaWallFlick")
			end)
		else
			local look = CFrame.lookAt(root.Position, root.Position + push)
			pcall(function()
				root.CFrame = look * CFrame.Angles(0, math.rad(60), 0)
			end)
			task.wait(0.08)
		end

		pcall(function()
			root.CFrame = CFrame.lookAt(root.Position, root.Position + push)
		end)

		task.wait(0.03)
		kick()
		finish()
	end)
end

-- Cooldown tracking for real shots and throws.
task.spawn(function()
	local ok, service = pcall(function()
		return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"))
	end)

	if not ok or type(service) ~= "table" or not service.GunFired then
		return
	end

	track(service.GunFired.OnClientEvent:Connect(function(tool)
		local character = localPlayer.Character

		if not character or typeof(tool) ~= "Instance" or not tool:IsDescendantOf(character) then
			return
		end

		Combat.gunCooldown = true
		HUD.cooldown("Shoot", COOLDOWN.Shoot, "SHOOT\nMURDERER")

		task.delay(COOLDOWN.Shoot, function()
			Combat.gunCooldown = false
		end)
	end))
end)

local function hookThrowAnimation()
	local humanoid = getHumanoid()
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if Combat.animConnection then
		pcall(function()
			Combat.animConnection:Disconnect()
		end)

		Combat.animConnection = nil
	end

	if not animator then
		return
	end

	Combat.animConnection = animator.AnimationPlayed:Connect(function(track_)
		local animation = track_ and track_.Animation

		if not animation or animation.Name ~= "ThrowKnife" or Combat.knifeCooldown then
			return
		end

		local cooldown = Combat.throwCooldown(Combat.getTool("Knife"))
		Combat.knifeCooldown = true
		HUD.cooldown("Throw", cooldown, "THROW\nKNIFE")

		task.delay(cooldown, function()
			Combat.knifeCooldown = false
		end)
	end)
end

hookThrowAnimation()

track(localPlayer.CharacterAdded:Connect(function(character)
	character:WaitForChild("Humanoid")
	task.wait(0.3)
	hookThrowAnimation()
	Combat.syncBombCooldown()
	HUD.clearCooldown("Bomb")
	Combat.lastBomb = 0

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		track(humanoid.Died:Connect(function()
			Combat.lastBomb = 0
			HUD.clearCooldown("Bomb")
		end))
	end
end))

Combat.syncBombCooldown()
Combat.startVelocityTracker()

------------------------------------------------------------------ silent aim / triggerbot / knife

-- getconnections helpers used to mute the default tool shot while the silent versions fire.
local function muteActivated(toolName, store)
	for _, connection in ipairs(store) do
		pcall(function()
			connection:Enable()
		end)
	end

	table.clear(store)

	if not getconnections then
		return false
	end

	return (pcall(function()
		local tool = localPlayer.Character and localPlayer.Character:FindFirstChild(toolName)

		if not tool then
			return
		end

		for _, connection in ipairs(getconnections(tool.Activated)) do
			connection:Disable()
			table.insert(store, connection)
		end
	end))
end

local function unmute(store)
	for _, connection in ipairs(store) do
		pcall(function()
			connection:Enable()
		end)
	end

	table.clear(store)
end

local function watchTool(toolName, store, isOn, conns)
	local function hook(character)
		if not character then
			return
		end

		table.insert(conns, character.ChildAdded:Connect(function(child)
			if child.Name == toolName and child:IsA("Tool") and isOn() then
				task.wait(0.1)
				muteActivated(toolName, store)
			end
		end))
	end

	hook(localPlayer.Character)

	table.insert(conns, localPlayer.CharacterAdded:Connect(function(character)
		if not isOn() then
			return
		end

		task.wait(1)
		muteActivated(toolName, store)
		hook(character)
	end))
end

local Silent = { on = false, muted = {}, conns = {}, connection = nil }

function Silent.start()
	if Silent.connection then
		return
	end

	muteActivated("Gun", Silent.muted)

	if not getconnections then
		notify("Silent Aim", "Your executor has no getconnections - the normal shot fires too.", "error")
	end

	watchTool("Gun", Silent.muted, function()
		return Silent.on
	end, Silent.conns)

	Silent.connection = localPlayer:GetMouse().Button1Down:Connect(function()
		if not Silent.on then
			return
		end

		local character = localPlayer.Character
		local gun = character and character:FindFirstChild("Gun")
		local shoot = gun and gun:FindFirstChild("Shoot")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if not shoot or not root then
			return
		end

		local murderer = getMurderer()
		local valid = murderer and murderer ~= localPlayer and isAlive(murderer)
		local aim = nil

		if valid then
			local murdererRoot = murderer.Character:FindFirstChild("HumanoidRootPart")

			if murdererRoot and (root.Position - murdererRoot.Position).Magnitude <= 300 then
				if Combat.wallCheck and not Combat.wallbang and not Combat.hasLineOfSight(murderer.Character, root) then
					notify("Wall Detected!", "Murderer is behind a wall.", "error")
				else
					aim = Combat.aimAt(murderer, murdererRoot)
				end
			end
		end

		aim = aim or Combat.mouseAimPoint()

		if not aim then
			return
		end

		local attachment = root:FindFirstChild("GunRaycastAttachment")

		if Combat.wallbang and valid then
			shoot:FireServer(CFrame.new(aim + Vector3.new(0, 1.5, 0)), CFrame.new(aim))
		else
			shoot:FireServer(attachment and attachment.WorldCFrame or CFrame.new(root.Position), CFrame.new(aim))
		end
	end)
end

function Silent.stop()
	if Silent.connection then
		pcall(function()
			Silent.connection:Disconnect()
		end)

		Silent.connection = nil
	end

	unmute(Silent.muted)
	disconnectAll(Silent.conns)
end

local Trigger = { enabled = false, connection = nil, delay = 0.18, fov = 60, last = 0 }

function Trigger.start()
	if Trigger.connection then
		return
	end

	Trigger.connection = RunService.Heartbeat:Connect(function()
		if not Trigger.enabled or tick() - Trigger.last < Trigger.delay then
			return
		end

		pcall(function()
			if getSheriff() ~= localPlayer then
				return
			end

			local character = localPlayer.Character
			local gun = character and character:FindFirstChild("Gun")
			local shoot = gun and gun:FindFirstChild("Shoot")
			local murderer = getMurderer()

			if not shoot or not murderer or murderer == localPlayer or not isAlive(murderer) then
				return
			end

			local targetRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
			local myRoot = character:FindFirstChild("HumanoidRootPart")

			if not targetRoot or not myRoot then
				return
			end

			local aim = Combat.aimAt(murderer, targetRoot)
			local camera = Workspace.CurrentCamera
			local point, onScreen = camera:WorldToViewportPoint(aim)

			if not onScreen or (Vector2.new(point.X, point.Y) - camera.ViewportSize / 2).Magnitude > Trigger.fov then
				return
			end

			if Combat.wallCheck and not Combat.wallbang and not Combat.hasLineOfSight(murderer.Character, myRoot) then
				return
			end

			if (myRoot.Position - targetRoot.Position).Magnitude > 300 then
				return
			end

			Trigger.last = tick()
			local attachment = myRoot:FindFirstChild("GunRaycastAttachment")

			if Combat.wallbang then
				shoot:FireServer(CFrame.new(aim + Vector3.new(0, 1.5, 0)), CFrame.new(aim))
			else
				shoot:FireServer(attachment and attachment.WorldCFrame or CFrame.new(myRoot.Position), CFrame.new(aim))
			end
		end)
	end)
end

function Trigger.stop()
	if Trigger.connection then
		pcall(function()
			Trigger.connection:Disconnect()
		end)

		Trigger.connection = nil
	end
end

-- Stabbing
local function stab(targets, useEquipped)
	local knife

	if useEquipped then
		knife = localPlayer.Character and localPlayer.Character:FindFirstChild("Knife")
	else
		knife = Combat.equip("Knife")
	end

	local events = knife and knife:FindFirstChild("Events")

	if not events then
		return 0
	end

	local stabbed = events:FindFirstChild("KnifeStabbed")
	local touched = events:FindFirstChild("HandleTouched")

	if not (stabbed and touched) then
		return 0
	end

	pcall(function()
		stabbed:FireServer()
	end)

	local count = 0

	for _, player in ipairs(targets) do
		local character = player.Character
		local part = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChildWhichIsA("BasePart"))

		if part then
			pcall(function()
				touched:FireServer(part)
			end)

			count += 1
		end
	end

	return count
end

local function livingTargets(radius)
	local myRoot = rootOf(localPlayer)
	local list = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local root = player ~= localPlayer and rootOf(player)

		if root and isAlive(player) then
			if not radius or not myRoot or (root.Position - myRoot.Position).Magnitude <= radius then
				list[#list + 1] = player
			end
		end
	end

	return list
end

function Combat.killTarget(name)
	if not name or name == "" then
		notify("No target", "Pick a player first.", "error")
		return
	end

	if getMurderer() ~= localPlayer then
		notify("Not Murderer!", "You don't have the knife.", "error")
		return
	end

	local player = Players:FindFirstChild(name)

	if not player then
		notify("Gone", name .. " isn't in the server.", "error")
		return
	end

	local count = stab({ player })
	notify(count > 0 and "Stabbed" or "Failed", count > 0 and ("Stabbed " .. name .. ".") or ("Couldn't reach " .. name .. "."), (count == 0) and "error" or nil)
end

function Combat.killAll()
	if getMurderer() ~= localPlayer then
		notify("Not Murderer!", "You don't have the knife.", "error")
		return
	end

	local count = stab(livingTargets(nil))
	notify("Kill All", ("Stabbed %d player%s."):format(count, count == 1 and "" or "s"))
end

function Combat.killSheriff()
	local sheriff = getSheriff()

	if not sheriff then
		notify("No Sheriff", "Nobody is holding the gun right now.", "error")
		return
	end

	Combat.killTarget(sheriff.Name)
end

-- Knife hitbox
local Hitbox = { on = true, show = false, mult = 1, radius = 1.5, NORMAL = 1.5, STEP = 0.1 }

function Hitbox.setMult(value)
	Hitbox.mult = value
	Hitbox.radius = Hitbox.NORMAL * (1 + (value - 1) * Hitbox.STEP)
end

function Hitbox.start()
	Hitbox.stop()

	Hitbox.clickConnection = localPlayer:GetMouse().Button1Down:Connect(function()
		if Hitbox.on and getMurderer() == localPlayer then
			stab(livingTargets(Hitbox.radius), true)
		end
	end)

	Hitbox.thrownConnection = CollectionService:GetInstanceAddedSignal("ThrowingKnife"):Connect(function(knifePart)
		if not Hitbox.on then
			return
		end

		task.spawn(function()
			local link = knifePart:WaitForChild("HandleLink", 3)
			local handle = link and link.Value
			local tool = handle and handle.Parent
			local character = localPlayer.Character

			if not (tool and character and tool:IsDescendantOf(character)) then
				return
			end

			local events = tool:FindFirstChild("Events")
			local stabbed = events and events:FindFirstChild("KnifeStabbed")
			local touched = events and events:FindFirstChild("HandleTouched")

			if not (stabbed and touched) then
				return
			end

			local hit = {}

			while knifePart.Parent and Hitbox.on do
				local position = knifePart:IsA("BasePart") and knifePart.Position or (knifePart:IsA("Model") and knifePart:GetPivot().Position)

				if position then
					for _, player in ipairs(Players:GetPlayers()) do
						local root = player ~= localPlayer and not hit[player] and rootOf(player)

						if root and isAlive(player) and (root.Position - position).Magnitude <= Hitbox.radius then
							hit[player] = true

							pcall(function()
								stabbed:FireServer()
							end)

							pcall(function()
								touched:FireServer(root)
							end)
						end
					end
				end

				task.wait(0.05)
			end
		end)
	end)
end

function Hitbox.stop()
	for _, key in ipairs({ "clickConnection", "thrownConnection" }) do
		if Hitbox[key] then
			pcall(function()
				Hitbox[key]:Disconnect()
			end)

			Hitbox[key] = nil
		end
	end
end

function Hitbox.hideBall()
	if Hitbox.showConnection then
		pcall(function()
			Hitbox.showConnection:Disconnect()
		end)

		Hitbox.showConnection = nil
	end

	if Hitbox.ball then
		pcall(function()
			Hitbox.ball:Destroy()
		end)

		Hitbox.ball = nil
	end
end

function Hitbox.showBall()
	Hitbox.hideBall()

	local part = Instance.new("Part")
	part.Name = "MagmaHitboxSphere"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 90, 90)
	part.Transparency = 0.88
	part.Size = Vector3.one * Hitbox.radius * 2
	part.Parent = Workspace.CurrentCamera
	Hitbox.ball = part

	Hitbox.showConnection = RunService.RenderStepped:Connect(function()
		local character = localPlayer.Character

		if not part.Parent or not character then
			return
		end

		local position = nil

		for _, tagged in ipairs(CollectionService:GetTagged("ThrowingKnife")) do
			local link = tagged:FindFirstChild("HandleLink")
			local handle = link and link.Value
			local tool = handle and handle.Parent

			if tool and tool:IsDescendantOf(character) then
				position = tagged:IsA("BasePart") and tagged.Position or (tagged:IsA("Model") and tagged:GetPivot().Position) or nil

				if position then
					break
				end
			end
		end

		if not position then
			local knife = character:FindFirstChild("Knife")
			local handle = knife and knife:FindFirstChild("Handle")
			position = handle and handle.Position
		end

		if not position then
			local root = character:FindFirstChild("HumanoidRootPart")
			position = root and root.Position
		end

		if position then
			part.Size = Vector3.one * Hitbox.radius * 2
			part.CFrame = CFrame.new(position)
		end
	end)
end

local SilentThrow = { on = false, muted = {}, conns = {}, connection = nil }

function SilentThrow.start()
	if SilentThrow.connection then
		return
	end

	muteActivated("Knife", SilentThrow.muted)

	if not getconnections then
		notify("Silent Throw", "Your executor has no getconnections - the normal throw fires too.", "error")
	end

	watchTool("Knife", SilentThrow.muted, function()
		return SilentThrow.on
	end, SilentThrow.conns)

	SilentThrow.connection = localPlayer:GetMouse().Button2Down:Connect(function()
		if not SilentThrow.on or getMurderer() ~= localPlayer then
			return
		end

		local target = Combat.nearestPlayer()

		if not target then
			return
		end

		local root = rootOf(localPlayer)

		if root and Combat.wallCheck and not Combat.hasLineOfSight(target.Character, root) then
			notify("Wall Detected!", target.Name .. " is behind a wall.", "error")
			return
		end

		local knife, character = nil, localPlayer.Character
		knife = Combat.equip("Knife")
		local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("HumanoidRootPart"))
		local aim = Combat.predict(target, 600, 0.95)
		local throw = knife and (knife:FindFirstChild("Throw") or (knife:FindFirstChild("Events") and knife.Events:FindFirstChild("KnifeThrown")))

		if not (throw and throw:IsA("RemoteEvent") and hand and aim) then
			return
		end

		local handle = knife:FindFirstChild("Handle")
		throw:FireServer(handle and handle.CFrame or CFrame.new(hand.Position), CFrame.new(aim))

		pcall(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			local animation = knife:FindFirstChild("ThrowKnife", true)

			if animator and animation then
				animator:LoadAnimation(animation):Play(0.1, 6, 1)
			end
		end)
	end)
end

function SilentThrow.stop()
	if SilentThrow.connection then
		pcall(function()
			SilentThrow.connection:Disconnect()
		end)

		SilentThrow.connection = nil
	end

	unmute(SilentThrow.muted)
	disconnectAll(SilentThrow.conns)
end

Hitbox.start()

-- X-Ray (client only)
local Xray = { on = false, original = {} }

function Xray.set(on)
	Xray.on = on

	if on then
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Transparency < 0.5 then
				local model = descendant:FindFirstAncestorWhichIsA("Model")

				if not (model and Players:GetPlayerFromCharacter(model)) then
					if Xray.original[descendant] == nil then
						Xray.original[descendant] = descendant.Transparency
					end

					descendant.Transparency = 0.5
				end
			end
		end
	else
		for part, transparency in next, Xray.original do
			pcall(function()
				if part.Parent then
					part.Transparency = transparency
				end
			end)
		end

		Xray.original = {}
	end
end

------------------------------------------------------------------ HUD definitions

local function toggleElement(element)
	if element then
		element:Set(not element.Value)
	end
end

HUD.defs = {
	Shoot = { text = "SHOOT\nMURDERER", accent = Color3.fromHex("#257AF7"), icon = "crosshair", action = Combat.shootMurderer },
	Grab = { text = "GRAB\nGUN", accent = Color3.fromHex("#10C550"), icon = "hand", action = Combat.grabGun },
	Bomb = { text = "BOMB\nJUMP", accent = Color3.fromHex("#F97316"), icon = "bomb", action = Combat.bombJump },
	Throw = { text = "THROW\nKNIFE", accent = Color3.fromHex("#EF4444"), icon = "sword", action = Combat.throwKnife },
	WallHop = { text = "WALL\nHOP", accent = Color3.fromHex("#A855F7"), icon = "climb", action = Combat.wallHop },
	KillAll = { text = "KILL ALL\nMURDER\nONLY", accent = Color3.fromHex("#DC2626"), icon = "badge", action = Combat.killAll },
	KillSheriff = { text = "KILL\nSHERIFF", accent = Color3.fromHex("#DC2626"), icon = "skull", action = Combat.killSheriff },
	Xray = {
		text = "FREE\nX-RAY",
		accent = Color3.fromHex("#FACC15"),
		icon = "xray",
		action = function()
			toggleElement(els.xray)
		end,
	},
	Fly = {
		text = "FLY",
		accent = Color3.fromHex("#38BDF8"),
		icon = "plane",
		action = function()
			toggleElement(els.fly)
		end,
	},
	Noclip = {
		text = "NOCLIP",
		accent = Color3.fromHex("#94A3B8"),
		icon = "ghost",
		action = function()
			toggleElement(els.noclip)
		end,
	},
}

------------------------------------------------------------------ data readers

local Data = {}

function Data.profile()
	return safeRequire(function()
		return ReplicatedStorage.Modules.ProfileData
	end)
end

function Data.owned()
	local profile = Data.profile()
	local owned = profile and profile.Materials and profile.Materials.Owned
	return type(owned) == "table" and owned or nil
end

function Data.xp()
	local profile = Data.profile()
	return profile and tonumber(profile.NewXP) or nil
end

function Data.level()
	local xp = Data.xp()

	if not xp then
		return nil
	end

	local module = safeRequire(function()
		return ReplicatedStorage.Modules.LevelModule
	end)

	if not module or type(module.GetLevel) ~= "function" then
		return nil
	end

	local ok, level = pcall(module.GetLevel, xp)
	return ok and tonumber(level) or nil
end

function Data.shells()
	local owned = Data.owned()
	return owned and (tonumber(owned.SummerKey2026) or 0) or nil
end

function Data.coins()
	local owned = Data.owned()
	return owned and (tonumber(owned.Coins) or 0) or nil
end

------------------------------------------------------------------ autofarm

local Round

local Farm = {
	on = false,
	running = false,
	alive = false,
	map = nil,
	lastMap = nil,
	tween = nil,
	locked = false,
	speed = 23,
	sawCoins = false,
	target = nil,
	targetTime = 0,
	stuckTarget = nil,
	stuckSince = 0,
	fails = {},
	skips = {},
	clipParts = {},
	autoReset = false,
	resetRunning = false,
	flingWhenDone = false,
	flingFired = false,
	killWhenFull = false,
	killFired = false,
	hopWhenDead = true,
	antiAfk = false,
	diedMidRound = false,
}

function Farm.coinSkip(coin)
	local until_ = Farm.skips[coin]

	if not until_ then
		return false
	end

	if until_ < tick() then
		Farm.skips[coin] = nil
		Farm.fails[coin] = nil
		return false
	end

	return true
end

function Farm.coinFailed(coin)
	local count = (Farm.fails[coin] or 0) + 1
	Farm.fails[coin] = count

	if count >= 2 then
		Farm.skips[coin] = tick() + 20
	end
end

function Farm.nearestCoin()
	local root = rootOf(localPlayer)
	local container = root and Farm.map and Farm.map:FindFirstChild("CoinContainer")

	if not container then
		return nil
	end

	local best, bestDistance = nil, math.huge

	for _, coin in ipairs(container:GetChildren()) do
		if coin.Name == "Coin_Server" and not coin:GetAttribute("Collected") and not Farm.coinSkip(coin) then
			local distance = (root.Position - coin.Position).Magnitude

			if distance < bestDistance then
				best, bestDistance = coin, distance
			end
		end
	end

	return best
end

function Farm.roundTime()
	local timer = Workspace:FindFirstChild("RoundTimerPart")
	return timer and tonumber(timer:GetAttribute("Time")) or 0
end

function Farm.bagCount()
	local ok, result = pcall(function()
		local main = localPlayer.PlayerGui.MainGUI
		local container = inLobby() and main.Lobby.Dock.CoinBags.Container or main.Game.CoinBags.Container
		local chosen = nil

		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("GuiObject") and child:FindFirstChild("CurrencyFrame") then
				if child.Visible then
					chosen = child
					break
				elseif child.Name == "Coin" and not chosen then
					chosen = child
				end
			end
		end

		if not chosen then
			return 0
		end

		local full = chosen:FindFirstChild("Full")

		if full and full.Visible then
			return 999
		end

		local frame = chosen:FindFirstChild("CurrencyFrame")
		local text = frame and frame:FindFirstChild("Icon")
		text = text and text:FindFirstChild("Coins")
		text = text and text.Text

		if text and (string.lower(text):find("full") or string.lower(text):find("max")) then
			return 999
		end

		return tonumber(text) or 0
	end)

	return ok and result or 0
end

function Farm.setClip(on)
	if on then
		if not Farm.clipConnection then
			Farm.clipConnection = RunService.Stepped:Connect(function()
				local character = localPlayer.Character

				if character then
					for _, descendant in ipairs(character:GetDescendants()) do
						if descendant:IsA("BasePart") and descendant.CanCollide then
							Farm.clipParts[descendant] = true
							descendant.CanCollide = false
						end
					end
				end
			end)
		end
	else
		if Farm.clipConnection then
			Farm.clipConnection:Disconnect()
			Farm.clipConnection = nil
		end

		restoreCollision(Farm.clipParts)
	end
end

function Farm.lock(on)
	local character = localPlayer.Character
	local torso = character and character:FindFirstChild("UpperTorso")

	if not torso then
		return
	end

	local gyro = torso:FindFirstChild("MagmaFarmGyro")
	local velocity = torso:FindFirstChild("MagmaFarmVelocity")

	if on then
		if gyro or velocity then
			return
		end

		local root = rootOf(localPlayer)
		local humanoid = character:FindFirstChild("Humanoid")

		if not root or not humanoid then
			return
		end

		local flat = CFrame.new(root.Position) * CFrame.Angles(math.pi / 2, 0, math.pi / 2)
		Farm.setClip(true)

		gyro = Instance.new("BodyGyro")
		gyro.Name = "MagmaFarmGyro"
		gyro.P = 90000
		gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
		gyro.CFrame = flat
		gyro.Parent = torso

		velocity = Instance.new("BodyVelocity")
		velocity.Name = "MagmaFarmVelocity"
		velocity.Velocity = Vector3.zero
		velocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		velocity.Parent = torso

		root.CFrame = flat
		humanoid.PlatformStand = true
	else
		local humanoid = character:FindFirstChild("Humanoid")

		if humanoid then
			if gyro then
				gyro:Destroy()
			end

			if velocity then
				velocity:Destroy()
			end

			humanoid.PlatformStand = false
			Farm.setClip(false)
		end
	end
end

function Farm.underMapCFrame()
	if not Farm.map then
		return nil
	end

	local position = nil
	local spawns = Farm.map:FindFirstChild("Spawns")

	if spawns then
		for _, child in ipairs(spawns:GetChildren()) do
			if child:IsA("BasePart") then
				position = child.Position
				break
			end
		end
	end

	if not position then
		local ok, pivot = pcall(function()
			return Farm.map:GetPivot()
		end)

		if ok and pivot then
			position = pivot.Position
		end
	end

	return position and CFrame.new(position.X, position.Y - 15, position.Z) or nil
end

function Farm.hideUnderMap(root)
	local cframe = Farm.underMapCFrame()

	if not cframe then
		return false
	end

	Farm.lock(true)
	Farm.locked = true

	if (root.Position - cframe.Position).Magnitude > 5 then
		root.Velocity = Vector3.zero
		root.CFrame = cframe
	end

	return true
end

function Farm.teleportHome()
	if not Farm.map then
		return
	end

	local spawns = Farm.map:FindFirstChild("Spawns")

	if not spawns then
		return
	end

	local first, preferred = nil, nil

	for _, child in ipairs(spawns:GetChildren()) do
		if child:IsA("BasePart") then
			first = first or child

			if child.Name == "Spawn" or child.Name == "PlayerSpawn" or child.Name == "SpawnLocation" then
				preferred = child
			end
		end
	end

	local spawn = preferred or first
	local root = rootOf(localPlayer)

	if not spawn or not root then
		return
	end

	local humanoid = getHumanoid()

	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	root.Velocity = Vector3.zero
	root.RotVelocity = Vector3.zero
	root.CFrame = CFrame.new(spawn.Position.X, spawn.Position.Y + spawn.Size.Y / 2 + 4, spawn.Position.Z)
end

function Farm.stopFlight()
	if not Farm.locked then
		return
	end

	Farm.locked = false
	Farm.target = nil

	if Farm.tween then
		Farm.tween:Cancel()
		Farm.tween = nil
	end

	Farm.lock(false)

	if Farm.roundTime() > 0 and Farm.map then
		Farm.teleportHome()
	end
end

function Farm.inActiveRound()
	if inLobby() or not Farm.alive then
		return false
	end

	local map = findMap()
	local humanoid = getHumanoid()

	if not map or not humanoid or humanoid.Health <= 0 then
		return false
	end

	Farm.map = map
	return true
end

function Farm.finishFling()
	if not Farm.flingWhenDone or Farm.flingFired or Fling.active then
		return
	end

	local earned = Round.coinsAuth or Round.coins or 0

	if earned <= 0 and Farm.bagCount() <= 0 then
		return
	end

	earned = earned > 0 and earned or Farm.bagCount()
	local murderer = getMurderer()

	if not murderer or murderer == localPlayer or not murderer.Character then
		return
	end

	Farm.flingFired = true

	task.spawn(function()
		if Farm.autoReset then
			notify("Farm Done!", "Collected " .. comma(earned) .. " coins. Resetting, then flinging " .. murderer.Name .. "...")
			local humanoid = getHumanoid()

			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end

			local started = tick()
			local ready = false

			repeat
				task.wait(0.2)
				local character = localPlayer.Character
				local newHumanoid = character and character:FindFirstChildOfClass("Humanoid")
				ready = newHumanoid ~= nil and newHumanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
			until ready or tick() - started > 12

			if not ready then
				return
			end

			task.wait(0.6)
			murderer = getMurderer()

			if not murderer or murderer == localPlayer or not murderer.Character then
				return
			end
		else
			notify("Farm Done!", "Collected " .. comma(earned) .. " coins. Flinging " .. murderer.Name .. "...")
		end

		pcall(Fling.run, murderer)
	end)
end

function Farm.step()
	if not localPlayer.Character then
		Farm.alive = false
	else
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local extras = remotes and remotes:FindFirstChild("Extras")
		local getData = extras and extras:FindFirstChild("GetPlayerData")

		if getData then
			local ok, result = pcall(function()
				return getData:InvokeServer()
			end)

			if ok and result then
				local entry = result[localPlayer.Name]
				Farm.alive = entry ~= nil and not entry.Dead and not entry.Killed
			end
		end
	end

	Farm.map = findMap() or Farm.map

	if Farm.map ~= Farm.lastMap then
		Farm.lastMap = Farm.map
		Farm.sawCoins = false
		Farm.flingFired = false
		Farm.killFired = false
		Farm.fails = {}
		Farm.skips = {}
	end

	local root = rootOf(localPlayer)

	if Farm.alive and Farm.map and root and not Farm.sawCoins and not Farm.nearestCoin() then
		if Farm.hideUnderMap(root) then
			return
		end
	end

	if Farm.roundTime() <= 0 then
		Farm.stopFlight()
		return
	end

	local bag = Farm.bagCount()
	local limit = localPlayer:GetAttribute("Elite") and 50 or 40

	if limit <= bag then
		Farm.stopFlight()
		Farm.finishFling()

		if Farm.killWhenFull and not Farm.killFired and getMurderer() == localPlayer then
			Farm.killFired = true
			task.spawn(function()
				pcall(Combat.killAll)
			end)
		end

		return
	end

	if not (Farm.alive and localPlayer.Character) then
		Farm.stopFlight()
		return
	end

	local coin = root and Farm.nearestCoin()

	if root and coin then
		Farm.sawCoins = true

		if coin ~= Farm.target or Farm.target:GetAttribute("Collected") then
			Farm.target = coin
			Farm.locked = true
			Farm.targetTime = tick()

			if Farm.tween then
				Farm.tween:Cancel()
				Farm.tween = nil
			end

			Farm.lock(true)

			local position = coin.CFrame
			local duration = (root.Position - coin.Position).Magnitude / Farm.speed

			if duration > 15 then
				duration = 3
			end

			duration = math.max(duration, 0.05)
			root.Velocity = Vector3.zero

			Farm.tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
				CFrame = CFrame.new(position.X, position.Y - 3.5, position.Z) * CFrame.Angles(math.pi / 2, 0, math.pi / 2),
			})

			Farm.tween:Play()
			root.Velocity = Vector3.zero
		else
			local distance = (root.Position - coin.Position).Magnitude

			if distance <= 6 and not coin:GetAttribute("Collected") then
				coin.CFrame = CFrame.new(root.Position + Vector3.new(math.random(-80, 80) / 100, math.random(-50, 300) / 100, math.random(-80, 80) / 100))

				if (coin.Position - root.Position).Magnitude > 0.1 then
					root.CFrame = root.CFrame * CFrame.new(0, math.random(-20, 20) / 100, math.random(-20, 20) / 100)
				end

				if Farm.stuckTarget ~= coin then
					Farm.stuckTarget = coin
					Farm.stuckSince = tick()
				end

				if tick() - Farm.stuckSince > 2 then
					Farm.stuckTarget = nil
					Farm.stuckSince = 0
					Farm.target = nil
				end
			elseif distance > 6 and tick() - Farm.targetTime > 4 then
				Farm.coinFailed(coin)
				Farm.target = nil
				Farm.stuckTarget = nil
				Farm.stuckSince = 0
			end
		end
	elseif root and Farm.sawCoins then
		Farm.stopFlight()
		Farm.finishFling()
	end
end

function Farm.start()
	if Farm.running then
		return
	end

	Farm.running = true
	Farm.map = findMap() or Farm.map

	task.spawn(function()
		while alive and Farm.on do
			task.wait(0.1)
			local ok, err = pcall(Farm.step)

			if not ok then
				warn("[Magma] autofarm: " .. tostring(err))
			end
		end

		Farm.running = false
	end)
end

function Farm.stop()
	Farm.on = false

	if Farm.tween then
		pcall(function()
			Farm.tween:Cancel()
		end)

		Farm.tween = nil
	end

	pcall(Farm.lock, false)
	Farm.locked = false
	Farm.target = nil

	local wasInRound = false

	pcall(function()
		if rootOf(localPlayer) then
			wasInRound = Farm.inActiveRound()

			if wasInRound then
				Farm.teleportHome()
			end
		end
	end)

	task.spawn(function()
		task.wait(0.35)

		pcall(function()
			local character = localPlayer.Character

			if not character then
				return
			end

			local cleaned = false

			for _, descendant in ipairs(character:GetDescendants()) do
				if descendant.Name == "MagmaFarmGyro" or descendant.Name == "MagmaFarmVelocity" then
					descendant:Destroy()
					cleaned = true
				end
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid and humanoid.PlatformStand then
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
				cleaned = true
			end

			if wasInRound and cleaned then
				Farm.teleportHome()
			end
		end)
	end)
end

function Farm.startAutoReset()
	if Farm.resetRunning then
		return
	end

	Farm.resetRunning = true

	task.spawn(function()
		while alive and Farm.autoReset do
			task.wait(1)

			pcall(function()
				if Farm.bagCount() >= 999 then
					local humanoid = getHumanoid()

					if humanoid then
						humanoid.Health = 0
					end
				end
			end)
		end

		Farm.resetRunning = false
	end)
end

function Farm.startAntiAfk()
	if Farm.idleConnection then
		return
	end

	Farm.idleConnection = localPlayer.Idled:Connect(function()
		if not Farm.antiAfk then
			return
		end

		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end)
end

function Farm.stopAntiAfk()
	if Farm.idleConnection then
		Farm.idleConnection:Disconnect()
		Farm.idleConnection = nil
	end
end

-- Fling the murderer after dying mid-round when "Fling Murderer When Done" is on.
track(localPlayer.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid", 5)

	if humanoid then
		track(humanoid.Died:Connect(function()
			local murderer = getMurderer()
			Farm.diedMidRound = murderer ~= nil and murderer ~= localPlayer
		end))
	end

	if not Farm.diedMidRound then
		return
	end

	Farm.diedMidRound = false

	if not Farm.flingWhenDone or Farm.flingFired then
		return
	end

	task.spawn(function()
		task.wait(1.2)

		if not Farm.flingWhenDone or Farm.flingFired or Fling.active then
			return
		end

		local murderer = getMurderer()

		if not murderer or murderer == localPlayer or not murderer.Character then
			return
		end

		Farm.flingFired = true
		notify("Out Of The Round", "Flinging " .. murderer.Name .. "...")
		pcall(Fling.run, murderer)
	end)
end))

-- God mode (reset trick)
local God = { busy = false, confirmUntil = 0 }

function God.myRole()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local extras = remotes and remotes:FindFirstChild("Extras")
	local getData = extras and extras:FindFirstChild("GetPlayerData")

	if not getData then
		return nil
	end

	local ok, result = pcall(function()
		return getData:InvokeServer()
	end)

	if not ok or type(result) ~= "table" then
		return nil
	end

	local entry = result[localPlayer.Name]
	return entry and entry.Role or nil
end

function God.run()
	if God.busy then
		return
	end

	local humanoid = getHumanoid()

	if not humanoid then
		notify("God Mode", "No character to reset.", "error")
		return
	end

	God.busy = true

	task.spawn(function()
		notify("God Mode", "Resetting, back on the map in a second...")

		pcall(function()
			humanoid.Health = 0
		end)

		task.wait(1)
		local started = tick()
		local root = nil

		repeat
			root = rootOf(localPlayer)

			if not root then
				task.wait(0.2)
			end
		until root or tick() - started > 10

		if root then
			pcall(Farm.teleportHome)
			notify("God Mode On!", "You cannot pick up coins or the gun now.")
		else
			notify("God Mode", "Respawn took too long - try again.", "error")
		end

		God.busy = false
	end)
end

function God.start()
	if God.busy then
		notify("God Mode", "Already running.", "error")
		return
	end

	local map = findMap()

	if not map then
		notify("No Map Yet", "Wait till the round starts, then try again.", "error")
		return
	end

	Farm.map = map

	task.spawn(function()
		local role = God.myRole()

		if role == "Murderer" then
			notify("Murderer", "This only works for Innocent and Sheriff.", "error")
			return
		end

		if role == "Sheriff" and os.clock() > God.confirmUntil then
			God.confirmUntil = os.clock() + 6
			notify("Lose your gun?", "God mode means you can't pick up coins or kill anyone. Press God Mode again within 6s to confirm.", "error")
			return
		end

		God.confirmUntil = 0
		God.run()
	end)
end

------------------------------------------------------------------ rounds / webhook

Round = {
	coins = 0,
	coinsAuth = nil,
	bags = {},
	role = nil,
	endRole = nil,
	start = nil,
	length = nil,
	lastTime = nil,
	win = nil,
	xp0 = nil,
	live = false,
}

function Round.roster()
	local module = safeRequire(function()
		return ReplicatedStorage.Modules.CurrentRoundClient
	end)

	return module and type(module.PlayerData) == "table" and module.PlayerData or nil
end

function Round.snapshot()
	local roster = Round.roster()
	local record = roster and roster[localPlayer.Name]

	if type(record) ~= "table" then
		return
	end

	if type(record.Coins) == "number" then
		Round.coinsAuth = record.Coins
	end

	if record.Role ~= nil then
		Round.endRole = tostring(record.Role)
		Round.role = Round.role or Round.endRole
	end
end

function Round.roleText()
	if Round.role and Round.endRole and Round.role ~= Round.endRole then
		return Round.role .. " -> " .. Round.endRole
	end

	return Round.endRole or Round.role or "unknown"
end

function Round.begin(length)
	Round.coins = 0
	Round.coinsAuth = nil
	Round.bags = {}
	Round.role = nil
	Round.endRole = nil
	Round.win = nil
	Round.length = length
	Round.lastTime = length
	Round.xp0 = Data.xp()
	Round.start = os.clock()
	Round.live = true
	Round.snapshot()
end

local WH = {
	url = "",
	on = false,
	broken = false,
	saidHello = false,
	queue = {},
	busy = false,
	thumbs = {},
	HOSTS = { "discord.com", "discordapp.com", "canary.discord.com", "ptb.discord.com" },
	SHELL_IMAGE = "https://static.wikia.nocookie.net/murder-mystery-2/images/e/e5/Shells.png/revision/latest?cb=20260724145424",
	COIN_ICON = "197012173",
	SHELL_COST = 120,
}

function WH.trimmedUrl()
	return (tostring(WH.url or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function WH.ready()
	if not alive or not WH.on or WH.broken then
		return false
	end

	local url = WH.trimmedUrl()

	for _, host in ipairs(WH.HOSTS) do
		if url:find("^https://" .. host:gsub("%.", "%%.") .. "/api/webhooks/") then
			return true
		end
	end

	return false
end

function WH.thumb(assetId)
	if not assetId then
		return nil
	end

	local key = tostring(assetId)

	if WH.thumbs[key] ~= nil then
		return WH.thumbs[key] or nil
	end

	local body = httpGet("https://thumbnails.roblox.com/v1/assets?assetIds=" .. key .. "&size=150x150&format=Png&isCircular=false")
	local image = body and body:match("\"imageUrl\"%s*:%s*\"([^\"]+)\"")

	if image and image:find("PrivateImage", 1, true) then
		image = nil
	end

	WH.thumbs[key] = image or false
	return image
end

function WH.avatar()
	if WH.avatarUrl ~= nil then
		return WH.avatarUrl or nil
	end

	local body = httpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(localPlayer.UserId) .. "&size=150x150&format=Png&isCircular=false")
	WH.avatarUrl = body and body:match("\"imageUrl\"%s*:%s*\"([^\"]+)\"") or false
	return WH.avatarUrl or nil
end

function WH.field(name, value, inline)
	return { name = name, value = value, inline = inline ~= false }
end

function WH.pad(fields)
	local inline, block = {}, {}

	for _, field in ipairs(fields) do
		table.insert(field.inline and inline or block, field)
	end

	while #inline % 3 ~= 0 do
		inline[#inline + 1] = { name = "\226\128\139", value = "\226\128\139", inline = true }
	end

	for _, field in ipairs(block) do
		inline[#inline + 1] = field
	end

	return inline
end

function WH.send(body)
	if not requestFunction then
		return false, "no request function", nil
	end

	local ok, response = pcall(requestFunction, {
		Url = WH.trimmedUrl(),
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = body,
	})

	if not ok then
		return false, "request failed", 5
	end

	local status = tonumber(type(response) == "table" and (response.StatusCode or response.Status) or nil) or 0

	if status == 204 or status == 200 or (status == 0 and type(response) == "table" and response.Success == true) then
		return true, tostring(status), nil
	end

	if status == 429 then
		local retry = tonumber((tostring(type(response) == "table" and response.Body or "")):match("\"retry_after\"%s*:%s*([%d%.]+)")) or 1
		return false, "429", math.min(60, retry + 0.25)
	end

	if status >= 500 then
		return false, tostring(status), 5
	end

	return false, tostring(status), nil
end

function WH.pump()
	if WH.busy then
		return
	end

	WH.busy = true

	task.spawn(function()
		while #WH.queue > 0 and alive and not WH.broken do
			local item = WH.queue[1]
			local ok, code, retry = WH.send(item.body)

			if ok then
				table.remove(WH.queue, 1)
				item.ok, item.code, item.done = true, code, true
				task.wait(0.35)
			elseif retry then
				task.wait(retry)
			else
				table.remove(WH.queue, 1)
				item.ok, item.code, item.done = false, code, true

				if code == "401" or code == "403" or code == "404" then
					WH.broken = true
					notify("Webhook Rejected", "Discord answered " .. code .. ". The webhook was deleted or revoked, so sending has stopped. Paste a new one.", "error")
				end
			end
		end

		if WH.broken then
			for _, item in ipairs(WH.queue) do
				item.done, item.ok, item.code = true, false, "stopped"
			end

			WH.queue = {}
		end

		WH.busy = false
	end)
end

function WH.post(payload)
	if not WH.ready() then
		return false, "no webhook set"
	end

	local embed = {
		title = payload.title,
		description = payload.body,
		color = 1,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		author = {
			name = localPlayer.Name .. "  (" .. localPlayer.DisplayName .. ")",
			url = "https://www.roblox.com/users/" .. tostring(localPlayer.UserId) .. "/profile",
			icon_url = WH.avatar(),
		},
		footer = { text = tostring(game.JobId) },
	}

	if payload.thumb then
		embed.thumbnail = { url = payload.thumb }
	end

	if payload.fields and #payload.fields > 0 then
		embed.fields = payload.fields
	end

	local message = { username = "Magma", allowed_mentions = { parse = {} }, embeds = { embed } }

	if payload.ping then
		message.content = "@everyone"
		message.allowed_mentions = { parse = { "everyone" } }
	end

	local ok, body = pcall(function()
		return HttpService:JSONEncode(message)
	end)

	if not ok then
		return false, "could not encode the payload"
	end

	local item = { body = body, done = false }

	if #WH.queue >= 40 then
		local dropped = table.remove(WH.queue, 1)
		dropped.done, dropped.ok, dropped.code = true, false, "dropped"
	end

	WH.queue[#WH.queue + 1] = item
	WH.pump()

	if not payload.wait then
		return true, "queued"
	end

	local started = os.clock()

	while not item.done and os.clock() - started < 25 do
		task.wait(0.1)
	end

	if not item.done then
		return false, "no answer from Discord"
	end

	return item.ok, item.code
end

function WH.hello()
	if WH.saidHello then
		return true, "already sent"
	end

	local coins = Data.coins()
	local shells = Data.shells()

	local ok, code = WH.post({
		title = "Magma logger started",
		body = "Logging as **" .. localPlayer.DisplayName .. "** since <t:" .. tostring(os.time()) .. ":f>.",
		thumb = WH.avatar(),
		wait = true,
		fields = WH.pad({
			WH.field("User ID", "`" .. tostring(localPlayer.UserId) .. "`"),
			WH.field("Coins", "`" .. comma(coins) .. "`"),
			WH.field("Shells", "`" .. comma(shells) .. "`"),
		}),
	})

	if ok then
		WH.saidHello = true
	end

	return ok, code
end

function WH.box(itemKey)
	if not WH.ready() then
		return
	end

	local items = safeRequire(function()
		return ReplicatedStorage.Database.Sync.Item
	end)

	local item = items and items[itemKey]
	item = type(item) == "table" and item or {}
	local rarity = tostring(item.Rarity or "Unknown")

	WH.post({
		ping = rarity:lower() == "godly",
		title = "Opened a Summer Box!",
		body = "Skin: **" .. tostring(item.ItemName or itemKey) .. "**\n\n**Info:**",
		thumb = WH.thumb(item.ItemID),
		fields = WH.pad({
			WH.field("Rarity", rarity),
			WH.field("Cost", comma(WH.SHELL_COST)),
			WH.field("Shells left", comma(Data.shells())),
		}),
	})
end

function WH.reward(amount, label, iconId)
	if not WH.ready() then
		return
	end

	local text = tostring(amount or ""):gsub("^%s*[xX]%s*", "")
	local number = tonumber((text:gsub("[^%d%.]", "")))
	local name = tostring(label or "reward")

	if name:lower():find("shell", 1, true) then
		local balance = Data.shells()
		local fields = {
			WH.field("Received", "+" .. (number and comma(number) or text) .. " Shells"),
			WH.field("Balance", comma(balance) .. " Shells"),
		}

		if type(balance) == "number" then
			local missing = WH.SHELL_COST - balance
			table.insert(fields, WH.field("Next box", missing > 0 and (comma(missing) .. " Shells left") or (comma(math.floor(balance / WH.SHELL_COST)) .. " boxes ready")))
		end

		WH.post({ title = utf8.char(128026) .. "  +" .. (number and comma(number) or text) .. " shells", thumb = WH.SHELL_IMAGE, fields = WH.pad(fields) })
		return
	end

	WH.post({
		title = "Reward claimed",
		body = "Received **" .. (number and comma(number) or text) .. "** " .. name .. ".",
		thumb = WH.thumb(iconId),
	})
end

function WH.round()
	if not WH.ready() then
		return
	end

	local coins = Data.coins()
	local shells = Data.shells()
	local gained = Round.coinsAuth or Round.coins or 0
	local seconds

	if Round.length and Round.lastTime then
		seconds = math.max(0, math.floor(Round.length - Round.lastTime))
	elseif Round.start then
		seconds = math.max(0, math.floor(os.clock() - Round.start))
	end

	local duration = seconds and string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60) or "?"
	local xp = Data.xp()
	local xpGain = xp and Round.xp0 and math.max(0, math.floor(xp - Round.xp0)) or nil

	WH.post({
		title = "Round Over.",
		thumb = WH.thumb(WH.COIN_ICON),
		body = "Collected: **+" .. comma(gained) .. "** Coins\n\n**Other Info:**",
		fields = {
			WH.field("Coins Balance", comma(coins)),
			WH.field("Played For", duration),
			WH.field("XP Gained", xpGain and ("+" .. comma(xpGain)) or "?"),
			WH.field("Shell Balance", comma(shells)),
			WH.field("Role", Round.roleText()),
			WH.field("Current Level", comma(Data.level())),
		},
	})
end

function Round.finish()
	if not Round.live then
		return
	end

	Round.live = false
	Round.snapshot()

	task.spawn(function()
		local started = os.clock()

		while os.clock() - started < 30 do
			if Round.win and (Data.xp() or 0) ~= (Round.xp0 or 0) then
				break
			end

			task.wait(0.25)
		end

		pcall(WH.round)
	end)
end

task.spawn(function()
	local timer = Workspace:WaitForChild("RoundTimerPart", 30)

	if timer then
		local time = tonumber(timer:GetAttribute("Time"))
		local length = tonumber(timer:GetAttribute("RoundLength"))

		if time and time > 0 then
			Round.begin(length)

			if length then
				Round.start = os.clock() - math.max(0, length - time)
			end
		end

		track(timer:GetAttributeChangedSignal("Time"):Connect(function()
			local current = tonumber(timer:GetAttribute("Time"))

			if current == nil then
				return
			end

			if current > 0 then
				Round.lastTime = current
			end

			if current > 0 and not Round.live then
				Round.begin(tonumber(timer:GetAttribute("RoundLength")))
			elseif current <= 0 and Round.live then
				Round.finish()
			end
		end))
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local gameplay = remotes and remotes:FindFirstChild("Gameplay")

	if not gameplay then
		return
	end

	local victory = gameplay:FindFirstChild("VictoryScreen")

	if victory then
		track(victory.OnClientEvent:Connect(function(_, endRole, win)
			if type(win) == "string" then
				Round.win = win
			end

			if type(endRole) == "string" and endRole ~= "" then
				Round.endRole = endRole
			end
		end))
	end

	local collected = gameplay:FindFirstChild("CoinCollected")

	if collected then
		track(collected.OnClientEvent:Connect(function(kind, amount)
			local value = tonumber(amount)

			if value then
				Round.bags[tostring(kind or "Coin")] = value
				local total = 0

				for _, bag in pairs(Round.bags) do
					total += bag
				end

				Round.coins = total
			end

			Round.snapshot()
		end))
	end

	local changed = gameplay:FindFirstChild("PlayerDataChanged")

	if changed then
		track(changed.OnClientEvent:Connect(Round.snapshot))
	end
end)

-- Shell reward popup
local Shells = { on = false, running = false }

function Shells.claim()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")

	if not playerGui then
		return false
	end

	local medium, claim = nil, nil
	local cross = playerGui:FindFirstChild("CrossPlatform")
	medium = cross and cross:FindFirstChild("NewItem") and cross.NewItem:FindFirstChild("Medium")

	if medium and medium.Visible then
		claim = medium:FindFirstChild("Container") and medium.Container:FindFirstChild("Claim")
	else
		local main = playerGui:FindFirstChild("MainGUI")
		local gameFrame = main and main:FindFirstChild("Game")
		medium = gameFrame and gameFrame:FindFirstChild("NewItem")

		if medium and medium.Visible then
			claim = medium:FindFirstChild("Container") and medium.Container:FindFirstChild("Claim")
		else
			medium = nil
		end
	end

	if not medium or not claim then
		return false
	end

	local amount = medium:FindFirstChild("Amount", true)
	local label = medium:FindFirstChild("Label", true)
	local icon = medium:FindFirstChild("Icon", true)
	local amountText = amount and amount.Text or nil
	local labelText = label and label.Text or nil
	local iconId = icon and tostring(icon.Image):match("%d+") or nil

	task.spawn(function()
		pcall(WH.reward, amountText, labelText, iconId)
	end)

	if getconnections then
		for _, signal in ipairs({ "Activated", "MouseButton1Click" }) do
			local ok, list = pcall(getconnections, claim[signal])

			if ok and list and #list > 0 then
				for _, connection in next, list do
					pcall(function()
						connection:Fire()
					end)
				end

				return true
			end
		end
	end

	return (pcall(function()
		local input = game:GetService("VirtualInputManager")
		local position = claim.AbsolutePosition
		local size = claim.AbsoluteSize
		local x = position.X + size.X / 2
		local y = position.Y + size.Y / 2 + 36
		input:SendMouseButtonEvent(x, y, 0, true, game, 1)
		task.wait(0.05)
		input:SendMouseButtonEvent(x, y, 0, false, game, 1)
	end))
end

function Shells.start()
	if Shells.running then
		return
	end

	Shells.running = true

	task.spawn(function()
		while alive and Shells.on do
			task.wait(0.5)
			pcall(Shells.claim)
		end

		Shells.running = false
	end)
end

-- Auto box opening
local Boxes = {
	LIST = {
		{ "Summer2026Box", "Summer Box '26" },
		{ "MysteryBox1", "Mystery Box #1" },
		{ "MysteryBox2", "Mystery Box #2" },
		{ "KnifeBox1", "Knife Box #1" },
		{ "KnifeBox2", "Knife Box #2" },
		{ "KnifeBox3", "Knife Box #3" },
		{ "KnifeBox4", "Knife Box #4" },
		{ "KnifeBox5", "Knife Box #5" },
		{ "GunBox1", "Gun Box #1" },
		{ "GunBox2", "Gun Box #2" },
		{ "GunBox3", "Gun Box #3" },
		{ "MLG Box", "Rainbow Box" },
	},
	CURRENCY = { Summer2026Box = "SummerKey2026" },
	NAMES = { SummerKey2026 = "Shells" },
	DELAY = 1,
	on = {},
	running = {},
	waiting = {},
}

function Boxes.price(key)
	local currency = Boxes.CURRENCY[key] or "Coins"
	local shop = safeRequire(function()
		return ReplicatedStorage.Database.Sync.NewShop
	end)

	local entry = shop and shop[key]
	local price = type(entry) == "table" and type(entry.Price) == "table" and entry.Price or nil
	return currency, price and tonumber(price[currency]) or nil
end

function Boxes.funds(currency)
	local owned = Data.owned()
	return owned and (tonumber(owned[currency]) or 0) or nil
end

function Boxes.open(key)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local shop = remotes and remotes:FindFirstChild("Shop")
	local remote = shop and shop:FindFirstChild("OpenCrate")

	if not remote then
		return nil, "the OpenCrate remote is gone"
	end

	local ok, result = pcall(function()
		return remote:InvokeServer(key, "MysteryBox", Boxes.CURRENCY[key] or "Coins")
	end)

	if not ok then
		return nil, tostring(result)
	end

	return result
end

function Boxes.start(key, title)
	if Boxes.running[key] then
		return
	end

	Boxes.running[key] = true

	task.spawn(function()
		local opened = 0

		while alive and Boxes.on[key] do
			local currency, price = Boxes.price(key)
			local funds = Boxes.funds(currency)

			if price and funds and funds < price then
				if not Boxes.waiting[key] then
					Boxes.waiting[key] = true
					notify(title, "Waiting for " .. comma(price - funds) .. " more " .. (Boxes.NAMES[currency] or currency) .. ". It opens on its own once you can afford one.")
				end

				task.wait(5)
			else
				Boxes.waiting[key] = false
				local result, reason = Boxes.open(key)

				if not result then
					local current = Boxes.funds(currency)

					if price and current and current < price then
						task.wait(5)
					else
						Boxes.on[key] = false

						if els.box and els.box[key] then
							els.box[key]:Set(false, true)
						end

						notify(title, (opened > 0 and ("Opened " .. opened .. ", then stopped: ") or "Nothing opened: ") .. (reason or "the server refused") .. ".", "error")
						break
					end
				else
					opened += 1

					task.spawn(function()
						pcall(WH.box, result)
					end)

					task.wait(Boxes.DELAY)
				end
			end
		end

		Boxes.running[key] = false
		Boxes.waiting[key] = false
	end)
end

------------------------------------------------------------------ skin spoofer

local Skins = { ready = false, list = {}, alive = true }

function Skins.loadMeshData()
	local cachedPath = "MagmaMM2/weapon.lua"
	local source = nil

	if isfile and readfile and isfile(cachedPath) then
		local ok, text = pcall(readfile, cachedPath)

		if ok and type(text) == "string" and #text > 100000 then
			source = text
		end
	end

	local cached = source ~= nil
	source = source or httpGet(MESH_URL)
	assert(source, "could not fetch mesh data from " .. MESH_URL)

	local chunk = loadstring(source .. "\nreturn MESHES_FULL")

	if not chunk and cached then
		source = httpGet(MESH_URL)
		chunk = source and loadstring(source .. "\nreturn MESHES_FULL")
		cached = false
	end

	assert(chunk, "mesh data failed to compile")

	if not cached and writefile then
		pcall(function()
			if makefolder and isfolder and not isfolder("MagmaMM2") then
				makefolder("MagmaMM2")
			end

			writefile(cachedPath, source)
		end)
	end

	local data = chunk()
	assert(type(data) == "table" and next(data) ~= nil, "mesh data file produced no MESHES_FULL table")
	return data
end

function Skins.build()
	local InsertService = game:GetService("InsertService")
	local EquipService = require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("EquipService"))
	local Sync = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"))
	local ProfileData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData"))
	local inventoryChanged = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory"):WaitForChild("InventoryDataChanged")
	local weapons = Sync.Weapons
	local conns = {}

	Skins.conns = conns

	local function trim(text)
		if type(text) == "string" then
			return (text:gsub("^%s+", ""):gsub("%s+$", ""))
		end

		return text
	end

	-- Catalog
	local meshes = {}

	for key, entry in pairs(Skins.loadMeshData()) do
		meshes[key] = entry
	end

	local sweetChroma = meshes.SweetChroma

	if sweetChroma and sweetChroma.Model and not meshes.Sweet then
		local function strip(node)
			local copy = { Class = node.Class, Id = node.Id, Name = node.Name, Props = node.Props, Tags = node.Tags }

			if node.Children then
				copy.Children = {}

				for _, child in ipairs(node.Children) do
					if not (child.Class == "Decal" and child.Name == "Chroma") then
						copy.Children[#copy.Children + 1] = strip(child)
					end
				end
			end

			return copy
		end

		local meta = {}

		for key, value in pairs(sweetChroma.Meta or {}) do
			meta[key] = value
		end

		meta.Chroma = nil
		meshes.Sweet = { Complete = false, Meta = meta, Model = strip(sweetChroma.Model) }
	end

	local RARITIES = { Godly = true, Ancient = true }
	local catalog = {}

	for key, data in pairs(meshes) do
		local entry = weapons[key]
		local name = type(entry) == "table" and tostring(entry.ItemName or "") or ""

		if type(entry) == "table" and (entry.ItemType == "Knife" or entry.ItemType == "Gun") and RARITIES[entry.Rarity] and name ~= "" and not name:match("^%?+$") then
			catalog[key] = data
		end
	end

	local function isChroma(key, data)
		if data.Meta and data.Meta.Chroma == true then
			return true
		end

		return key:sub(-6) == "Chroma"
	end

	-- Instance building
	local function applyProps(instance, props, skip)
		for key, value in pairs(props) do
			if not (skip and skip[key]) then
				if key == "MeshId" or key == "TextureId" or key == "TextureID" or key == "Texture" then
					value = trim(value)
				end

				pcall(function()
					instance[key] = value
				end)
			end
		end
	end

	local function createMeshPart(props)
		local meshId = trim(props.MeshId or "")
		local size = props.Size or Vector3.one
		local part = nil

		pcall(function()
			part = InsertService:CreateMeshPartAsync(meshId, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
		end)

		if part then
			pcall(function()
				part.Size = size
			end)

			return part
		end

		part = Instance.new("Part")
		part.Size = size
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh

		pcall(function()
			mesh.MeshId = meshId
		end)

		pcall(function()
			mesh.TextureId = trim(props.TextureID or "")
		end)

		mesh.Parent = part
		return part
	end

	local CHROMA_COLORS = {
		Color3.fromRGB(255, 0, 0),
		Color3.fromRGB(255, 255, 0),
		Color3.fromRGB(0, 255, 0),
		Color3.fromRGB(0, 255, 255),
		Color3.fromRGB(0, 0, 255),
		Color3.fromRGB(255, 0, 255),
	}

	local function chromaColor(time)
		local count = #CHROMA_COLORS
		local position = time % count
		local base = math.floor(position)
		return CHROMA_COLORS[base + 1]:Lerp(CHROMA_COLORS[(base + 1) % count + 1], position - base)
	end

	local function startChroma(overlay)
		local parts, decals, fires, meshesList = {}, {}, {}, {}
		local tagged = false

		for _, descendant in ipairs(overlay:GetDescendants()) do
			local attribute = descendant:GetAttribute("MM2Chroma")

			if attribute then
				tagged = true

				if attribute == "part" then
					parts[#parts + 1] = descendant
				elseif attribute == "decal" and descendant:IsA("Decal") then
					pcall(function()
						descendant.Texture = "rbxassetid://18363392181"
					end)

					decals[#decals + 1] = descendant
				elseif attribute == "fire" then
					fires[#fires + 1] = descendant
				end
			end
		end

		if not tagged then
			for _, descendant in ipairs(overlay:GetDescendants()) do
				if descendant:IsA("BasePart") and (descendant.Material == Enum.Material.Neon or descendant.Name:lower():find("light")) then
					parts[#parts + 1] = descendant
				elseif descendant:IsA("Decal") and descendant.Name:lower():find("chroma") then
					decals[#decals + 1] = descendant
				elseif descendant:IsA("Fire") then
					fires[#fires + 1] = descendant
				end
			end

			if #decals == 0 then
				fires[#fires + 1] = overlay
			end
		end

		local tinted = {}

		for _, item in ipairs(fires) do
			if item:IsA("BasePart") then
				tinted[item] = true
			end
		end

		for _, part in ipairs(parts) do
			tinted[part] = nil
		end

		for _, descendant in ipairs(overlay:GetDescendants()) do
			if descendant:IsA("SpecialMesh") and descendant.TextureId ~= "" and tinted[descendant.Parent] then
				meshesList[#meshesList + 1] = descendant
			end
		end

		if overlay:IsA("Part") and tinted[overlay] then
			local mesh = overlay:FindFirstChildWhichIsA("SpecialMesh")

			if mesh and mesh.TextureId ~= "" then
				meshesList[#meshesList + 1] = mesh
			end
		end

		if #parts == 0 and #decals == 0 and #fires == 0 and #meshesList == 0 then
			return nil
		end

		return RunService.Heartbeat:Connect(function()
			local now = os.clock()
			local color = chromaColor(now)

			for _, decal in ipairs(decals) do
				decal.Color3 = color
			end

			for _, mesh in ipairs(meshesList) do
				mesh.VertexColor = Vector3.new(color.R, color.G, color.B)
			end

			for _, item in ipairs(fires) do
				if item:IsA("Fire") or item:IsA("BasePart") then
					item.Color = color
				end
			end

			local step = math.floor(now * 1.8)

			for index, part in ipairs(parts) do
				part.Color = CHROMA_COLORS[(step + index - 1) % #CHROMA_COLORS + 1]
			end
		end)
	end

	local JOINTS = {
		WeldConstraint = true,
		Weld = true,
		Motor6D = true,
		RigidConstraint = true,
		Bone = true,
		Snap = true,
		ManualWeld = true,
		Rotate = true,
		RotateP = true,
		RotateV = true,
	}

	local function tagChroma(instance, node)
		if not (instance and node.Tags) then
			return
		end

		for _, tag in ipairs(node.Tags) do
			local kind = (tag == "ChromaPart" and "part") or (tag == "ChromaDecal" and "decal") or (tag == "ChromaFire" and "fire") or nil

			if kind then
				pcall(function()
					instance:SetAttribute("MM2Chroma", kind)
				end)
			end
		end
	end

	local function buildInstance(node)
		if JOINTS[node.Class] then
			return nil
		end

		local instance

		if node.Class == "MeshPart" then
			instance = createMeshPart(node.Props)
			applyProps(instance, node.Props, { MeshId = true, Size = true, RelCF = true, CanCollide = true })
		else
			local ok, created = pcall(Instance.new, node.Class)

			if not ok or not created then
				return nil
			end

			instance = created
			applyProps(instance, node.Props, { RelCF = true })
		end

		if node.Name then
			pcall(function()
				instance.Name = node.Name
			end)
		end

		tagChroma(instance, node)
		return instance
	end

	local function prepPart(part)
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
	end

	local buildChildren

	buildChildren = function(node, parent, rootPart, idMap, partList, beamList)
		for _, child in ipairs(node.Children or {}) do
			local instance = buildInstance(child)

			if instance then
				idMap[child.Id] = instance

				if instance:IsA("BasePart") then
					prepPart(instance)
					partList[#partList + 1] = { inst = instance, relcf = child.Props.RelCF }
					instance.Parent = rootPart
					buildChildren(child, instance, rootPart, idMap, partList, beamList)
				elseif instance:IsA("Attachment") then
					if child.Props.RelCF then
						pcall(function()
							instance.CFrame = child.Props.RelCF
						end)
					end

					instance.Parent = rootPart
					buildChildren(child, instance, rootPart, idMap, partList, beamList)
				elseif instance:IsA("Beam") or instance:IsA("Trail") then
					instance.Parent = parent
					beamList[#beamList + 1] = { inst = instance, a0 = child.Att0, a1 = child.Att1 }
					buildChildren(child, instance, rootPart, idMap, partList, beamList)
				else
					instance.Parent = parent
					buildChildren(child, instance, rootPart, idMap, partList, beamList)
				end
			else
				buildChildren(child, parent, rootPart, idMap, partList, beamList)
			end
		end
	end

	local function buildComposite(data)
		local model = data.Model

		if not model then
			return nil
		end

		local part

		if model.Class == "MeshPart" then
			part = createMeshPart(model.Props)
			applyProps(part, model.Props, { MeshId = true, Size = true, RelCF = true, CanCollide = true })
		else
			part = Instance.new("Part")
			applyProps(part, model.Props, { RelCF = true, CanCollide = true })
		end

		if model.Name then
			pcall(function()
				part.Name = model.Name
			end)
		end

		tagChroma(part, model)
		prepPart(part)

		local idMap = { [model.Id] = part }
		local partList, beamList = {}, {}
		buildChildren(model, part, part, idMap, partList, beamList)

		for _, beam in ipairs(beamList) do
			if beam.a0 and idMap[beam.a0] then
				pcall(function()
					beam.inst.Attachment0 = idMap[beam.a0]
				end)
			end

			if beam.a1 and idMap[beam.a1] then
				pcall(function()
					beam.inst.Attachment1 = idMap[beam.a1]
				end)
			end
		end

		return { root = part, parts = partList }
	end

	local EFFECT_CLASSES = {
		ParticleEmitter = true,
		Fire = true,
		Smoke = true,
		Sparkles = true,
		PointLight = true,
		SpotLight = true,
		SurfaceLight = true,
	}

	local function buildDisplay(data)
		local rootNode = nil
		local specialMeshes, decals, effects = {}, {}, {}

		for _, node in ipairs(data.Display or {}) do
			if node.Path == "(root)" then
				rootNode = node
			elseif node.Class == "SpecialMesh" then
				specialMeshes[#specialMeshes + 1] = node
			elseif node.Class == "Decal" or node.Class == "Texture" then
				decals[#decals + 1] = node
			elseif EFFECT_CLASSES[node.Class] then
				effects[#effects + 1] = node
			end
		end

		if not rootNode then
			return nil
		end

		local part

		if rootNode.Class == "MeshPart" then
			part = createMeshPart(rootNode.Props)
			applyProps(part, rootNode.Props, { MeshId = true, Size = true, CanCollide = true })
		else
			part = Instance.new("Part")
			part.Size = rootNode.Props.Size or Vector3.one
			applyProps(part, rootNode.Props, { Size = true, CanCollide = true })

			for _, node in ipairs(specialMeshes) do
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.FileMesh
				applyProps(mesh, node.Props)
				mesh.Parent = part
			end
		end

		prepPart(part)

		if rootNode.Name then
			pcall(function()
				part.Name = rootNode.Name
			end)
		end

		for _, node in ipairs(decals) do
			local decal = Instance.new("Decal")
			applyProps(decal, node.Props)

			if node.Name then
				pcall(function()
					decal.Name = node.Name
				end)
			end

			decal.Parent = part
		end

		for _, node in ipairs(effects) do
			local ok, effect = pcall(Instance.new, node.Class)

			if ok and effect then
				applyProps(effect, node.Props)

				if node.Name then
					pcall(function()
						effect.Name = node.Name
					end)
				end

				effect.Parent = part
			end
		end

		return { root = part, parts = {} }
	end

	local function buildOverlay(data)
		if data.Model then
			return buildComposite(data)
		end

		if data.Display then
			return buildDisplay(data)
		end

		return nil
	end

	local function weldBuilt(built, cframe)
		local root = built.root

		pcall(function()
			root.CFrame = cframe
		end)

		for _, entry in ipairs(built.parts) do
			if entry.relcf then
				pcall(function()
					entry.inst.CFrame = cframe * entry.relcf
				end)
			end

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = entry.inst
			weld.Part1 = root
			weld.Parent = entry.inst
		end

		return root
	end

	-- Mesh helpers
	local function dataMeshId(data)
		if data.Model then
			local model = data.Model

			if model.Class == "MeshPart" then
				return trim(model.Props.MeshId or "")
			end

			for _, child in ipairs(model.Children or {}) do
				if child.Class == "SpecialMesh" then
					return trim(child.Props.MeshId or "")
				end
			end

			return ""
		end

		for _, node in ipairs(data.Display or {}) do
			if node.Path == "(root)" and node.Class == "MeshPart" then
				return trim(node.Props.MeshId or "")
			end

			if node.Class == "SpecialMesh" then
				return trim(node.Props.MeshId or "")
			end
		end

		return ""
	end

	local function instanceMeshId(instance)
		if not instance then
			return ""
		end

		if instance:IsA("MeshPart") then
			return trim(instance.MeshId or "")
		end

		local mesh = instance:FindFirstChildWhichIsA("SpecialMesh", true)
		return mesh and trim(mesh.MeshId or "") or ""
	end

	local function customAttachmentCFrame(node)
		for _, child in ipairs(node.Children or {}) do
			if child.Class == "Attachment" and child.Name == "CustomAttachment" and child.Props and child.Props.RelCF then
				return child.Props.RelCF
			end

			local found = customAttachmentCFrame(child)

			if found then
				return found
			end
		end

		return nil
	end

	local function rootSize(data)
		if data.Model then
			return data.Model.Props and data.Model.Props.Size
		end

		for _, node in ipairs(data.Display or {}) do
			if node.Path == "(root)" then
				return node.Props and node.Props.Size
			end
		end

		return nil
	end

	local function sortedAxes(size)
		local axes = { { size.X, "X" }, { size.Y, "Y" }, { size.Z, "Z" } }

		table.sort(axes, function(a, b)
			return a[1] > b[1]
		end)

		return axes[1][2], axes[2][2], axes[3][2]
	end

	local function axisOrder(size)
		if not size then
			return nil
		end

		local a, b, c = sortedAxes(size)
		return a .. b .. c
	end

	local DISPLAY_OFFSETS = {
		Gun_ZYX = CFrame.new(0.12991, -3e-05, 0.075, 1, 0, 0, 0, 0.70713, 0.70708, 0, -0.70708, 0.70713),
		Gun_ZXY = CFrame.new(0.12991, 0, 0.07501, 2e-05, -0.5, -0.86603, 1, -4e-05, 5e-05, -6e-05, -0.86603, 0.5),
		Gun_XYZ = CFrame.new(-0.22989, 0.09821, 0.1, 1e-05, 0.98481, -0.17362, -1e-05, 0.17362, 0.98481, 1, -1e-05, 1e-05),
		Knife_YXZ = CFrame.new(0, 0, 0, -0.0446, -0.00031, -0.99901, 0.03549, 0.99937, -0.00189, 0.99837, -0.03553, -0.04456),
		Knife_ZYX = CFrame.new(0.00151, -0.12701, -0.15448, -0.99867, 0.03727, 0.03568, -0.04098, -0.15276, -0.98741, -0.03135, -0.98756, 0.15409),
		Knife_ZXY = CFrame.new(0.00151, -0.12701, -0.15448, -0.99867, 0.03727, 0.03568, -0.04098, -0.15276, -0.98741, -0.03135, -0.98756, 0.15409),
	}

	-- Attachment offsets learned from the real display part, keyed by mesh id.
	local learned = {}

	local function displayAttachment(instance)
		if not instance then
			return nil
		end

		return instance:FindFirstChild("CustomAttachment") or instance:FindFirstChildWhichIsA("Attachment")
	end

	local function learnDisplay(display)
		local meshId = instanceMeshId(display)
		local attachment = displayAttachment(display)

		if meshId ~= "" and attachment then
			learned[meshId] = attachment.CFrame
		end
	end

	local function displayOffset(data, slot)
		if data.Model then
			return customAttachmentCFrame(data.Model) or CFrame.identity
		end

		local meshId = dataMeshId(data)

		if meshId ~= "" and learned[meshId] then
			return learned[meshId]
		end

		local order = axisOrder(rootSize(data))
		return order and DISPLAY_OFFSETS[(data.Meta and data.Meta.ItemType or slot) .. "_" .. order] or CFrame.identity
	end

	local function displayCFrame(part, offset)
		local attachment = displayAttachment(part)
		return part.CFrame * (attachment and attachment.CFrame or CFrame.identity) * offset:Inverse()
	end

	-- Hiding the real visuals
	local function hideVisual(list, instance)
		if instance:IsA("BasePart") or instance:IsA("Decal") then
			list[#list + 1] = { inst = instance, prop = "Transparency", val = instance.Transparency }

			pcall(function()
				instance.Transparency = 1
			end)
		elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") or instance:IsA("Fire") or instance:IsA("Smoke") or instance:IsA("Sparkles") then
			list[#list + 1] = { inst = instance, prop = "Enabled", val = instance.Enabled }

			pcall(function()
				instance.Enabled = false
			end)
		end
	end

	local function restoreVisuals(list)
		for _, entry in ipairs(list) do
			pcall(function()
				entry.inst[entry.prop] = entry.val
			end)
		end
	end

	local function guardVisuals(list)
		local guards = {}

		for _, entry in ipairs(list) do
			local instance, prop = entry.inst, entry.prop

			guards[#guards + 1] = instance:GetPropertyChangedSignal(prop):Connect(function()
				if prop == "Enabled" then
					if instance.Enabled then
						instance.Enabled = false
					end
				elseif instance.Transparency ~= 1 then
					instance.Transparency = 1
				end
			end)
		end

		return guards
	end

	local function disconnectGuards(guards)
		for _, guard in ipairs(guards or {}) do
			pcall(function()
				guard:Disconnect()
			end)
		end
	end

	-- Display slot overlays (the knife/gun shown on the character)
	local function getDisplayRef(slot)
		local character = localPlayer.Character
		local reference = character and character:FindFirstChild("DisplayRef" .. slot)
		return reference and reference.Value or nil
	end

	local function waitDisplayRef(slot, timeout)
		local deadline = os.clock() + (timeout or 1)

		while os.clock() < deadline do
			local display = getDisplayRef(slot)

			if display then
				return display
			end

			task.wait(0.05)
		end

		return getDisplayRef(slot)
	end

	local displayOverlays, displayKeys, displayTokens = {}, {}, {}

	local function clearStrayDisplays(slot, keep)
		local container = Workspace:FindFirstChild("WeaponDisplays")

		if not container then
			return
		end

		for _, child in ipairs(container:GetChildren()) do
			if child ~= keep and child:GetAttribute("MM2VizSlot") == slot then
				pcall(function()
					child:Destroy()
				end)
			end
		end
	end

	local function removeDisplay(slot)
		clearStrayDisplays(slot)
		local entry = displayOverlays[slot]

		if not entry then
			return
		end

		if entry.chroma then
			pcall(function()
				entry.chroma:Disconnect()
			end)
		end

		if entry.overlay then
			pcall(function()
				entry.overlay:Destroy()
			end)
		end

		restoreVisuals(entry.hidden)
		displayOverlays[slot] = nil
	end

	local function applyDisplay(slot, key)
		if displayOverlays[slot] and displayKeys[slot] == key and key ~= nil then
			return
		end

		displayTokens[slot] = (displayTokens[slot] or 0) + 1
		local token = displayTokens[slot]
		removeDisplay(slot)

		local data = key and catalog[key]
		displayKeys[slot] = key

		if not data then
			return
		end

		local display = getDisplayRef(slot) or waitDisplayRef(slot, 1.5)

		if displayTokens[slot] ~= token or not display then
			return
		end

		learnDisplay(display)

		if instanceMeshId(display) == dataMeshId(data) and instanceMeshId(display) ~= "" then
			return
		end

		local offset = displayOffset(data, slot)
		local hidden = {}
		hideVisual(hidden, display)

		for _, descendant in ipairs(display:GetDescendants()) do
			hideVisual(hidden, descendant)
		end

		local built = buildOverlay(data)

		if not built or not built.root or displayTokens[slot] ~= token or not display.Parent then
			restoreVisuals(hidden)

			if built and built.root then
				built.root:Destroy()
			end

			return
		end

		weldBuilt(built, displayCFrame(display, offset))
		local root = built.root
		root:SetAttribute("MM2VizOverlay", true)
		root:SetAttribute("MM2VizSlot", slot)
		root.Parent = display.Parent or display

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = display
		weld.Parent = root

		clearStrayDisplays(slot, root)
		displayOverlays[slot] = { overlay = root, hidden = hidden, chroma = isChroma(key, data) and startChroma(root) or nil }
	end

	-- Held tool overlays
	local AXES = { X = Vector3.new(1, 0, 0), Y = Vector3.new(0, 1, 0), Z = Vector3.new(0, 0, 1) }
	local GRIP_BASIS = {
		Gun = { Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0) },
		Knife = { Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0) },
	}
	local GRIP_ROTATE = {
		Harvester = CFrame.Angles(0, 0, -math.pi / 2),
		Icepiercer = CFrame.Angles(0, 0, -math.pi / 2),
	}
	local GRIP_SKIP = { Sweet = true, SweetChroma = true }
	local GRIP_SHIFT = { Harvester = 0.5, Icepiercer = 0.5 }

	local function gripCFrame(tool, key, data, slot)
		if key and GRIP_SKIP[key] then
			return CFrame.identity
		end

		local size = rootSize(data)
		local basis = GRIP_BASIS[slot]

		if not (size and basis) then
			return CFrame.identity
		end

		local first, second, third = sortedAxes(size)
		local map = { [first] = basis[1], [second] = basis[2], [third] = basis[3] }

		if AXES[first]:Cross(AXES[second]):Dot(AXES[third]) < 0 then
			map[third] = -map[third]
		end

		local result = tool.Grip.Rotation * CFrame.fromMatrix(Vector3.new(), map.X, map.Y, map.Z)
		local rotate = key and GRIP_ROTATE[key]

		if rotate then
			result *= rotate
		end

		local shift = key and GRIP_SHIFT[key]

		if shift then
			result *= CFrame.new(AXES[first] * shift)
		end

		return result
	end

	local function stuckKnifeCFrame(partSize, data)
		local size = rootSize(data)

		if not size then
			return CFrame.identity
		end

		local a, b, c = sortedAxes(size)
		local pa, pb, pc = sortedAxes(partSize)
		local map = { [a] = AXES[pa], [b] = AXES[pb], [c] = AXES[pc] }

		if AXES[a]:Cross(AXES[b]):Dot(AXES[c]) ~= AXES[pa]:Cross(AXES[pb]):Dot(AXES[pc]) then
			map[c] = -map[c]
		end

		return CFrame.fromMatrix(Vector3.new(), map.X, map.Y, map.Z)
	end

	-- Icons
	local function iconFor(key, data)
		local prefix = key:match("^(.-)Chroma$") or key:match("^Chroma(.+)$")
		local meta = prefix and catalog[prefix] and catalog[prefix].Meta or data.Meta

		if not meta then
			return nil
		end

		if meta.ItemID then
			return ("rbxthumb://type=Asset&w=150&h=150&id=%d"):format(meta.ItemID)
		end

		return meta.Image
	end

	local iconContainers = setmetatable({}, { __mode = "k" })

	-- The backpack UI has no direct link to a tool, so rename the tool to find its row.
	local function findIconContainer(tool)
		local cached = iconContainers[tool]

		if cached and cached.Parent then
			return cached
		end

		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		local backpackUi = playerGui and playerGui:FindFirstChild("BackpackUI")
		local frame = backpackUi and backpackUi:FindFirstChild("BackpackFrame")

		if not frame then
			return nil
		end

		for _, child in ipairs(frame:GetChildren()) do
			local container = child:IsA("GuiObject") and child:FindFirstChild("Container")
			local nameLabel = container and container:FindFirstChild("NameLabel")

			if nameLabel and container:FindFirstChild("ToolIcon") then
				local originalName = child.Name
				local originalText = nameLabel.Text
				child.Name = originalName .. " "
				task.wait()
				local changedText = nameLabel.Text
				child.Name = originalName
				task.wait()
				nameLabel.Text = originalText

				if changedText == tool.Name then
					iconContainers[tool] = container
					return container
				end
			end
		end

		return nil
	end

	local function setBackpackIcon(tool, image)
		task.spawn(function()
			local container = findIconContainer(tool)

			if not container then
				return
			end

			local icon = container:FindFirstChild("ToolIcon")

			if icon then
				icon.Image = image
			end

			local nameLabel = container:FindFirstChild("NameLabel")

			if nameLabel then
				nameLabel.Text = image == "" and tool.Name or ""
			end
		end)
	end

	local function swapToolIcon(tool, textureId)
		if not textureId or textureId == "" then
			return nil
		end

		local previous = tool.TextureId
		tool.TextureId = textureId
		setBackpackIcon(tool, textureId)
		return previous
	end

	local function restoreToolIcon(tool, textureId)
		if not textureId then
			return
		end

		pcall(function()
			tool.TextureId = textureId
		end)

		setBackpackIcon(tool, textureId)
	end

	local SHOT_SOUNDS = {
		Harvester = "rbxassetid://7808472682",
		Icepiercer = "rbxassetid://7808472682",
		Raygun = "rbxassetid://92066070356304",
		RaygunChroma = "rbxassetid://92066070356304",
		Snowcannon = "rbxassetid://136161856273464",
		SnowcannonChroma = "rbxassetid://136161856273464",
		Gingerscope = "rbxassetid://74240492893421",
	}

	local function swapShotSound(tool, key)
		local soundId = SHOT_SOUNDS[key]
		local handle = soundId and tool:FindFirstChild("Handle")
		local sound = handle and handle:FindFirstChild("Gunshot")

		if not (sound and sound:IsA("Sound")) then
			return nil
		end

		local previous = sound.SoundId
		sound.SoundId = soundId
		return { sound = sound, old = previous }
	end

	local function restoreShotSound(entry)
		if entry and entry.sound then
			pcall(function()
				entry.sound.SoundId = entry.old
			end)
		end
	end

	local heldOverlays = {}

	local function isMine(instance)
		if instance:IsDescendantOf(localPlayer) then
			return true
		end

		local character = localPlayer.Character
		return character ~= nil and instance:IsDescendantOf(character)
	end

	local function removeHeld(tool)
		local entry = heldOverlays[tool]

		if not entry then
			return
		end

		if entry.chroma then
			pcall(function()
				entry.chroma:Disconnect()
			end)
		end

		if entry.overlay then
			pcall(function()
				entry.overlay:Destroy()
			end)
		end

		pcall(restoreToolIcon, tool, entry.icon)
		restoreShotSound(entry.shot)
		disconnectGuards(entry.guards)
		restoreVisuals(entry.hidden)
		heldOverlays[tool] = nil
	end

	local function applyHeld(tool, slot)
		if heldOverlays[tool] then
			return
		end

		local handle = tool:FindFirstChild("Handle") or tool:WaitForChild("Handle", 5)

		if not handle then
			return
		end

		local key = ProfileData.Weapons.Equipped[slot]
		local data = key and catalog[key]

		if not data then
			return
		end

		learnDisplay(handle)
		local built = buildOverlay(data)

		if not built or not built.root then
			return
		end

		local hidden = {}
		hideVisual(hidden, handle)

		for _, descendant in ipairs(handle:GetDescendants()) do
			hideVisual(hidden, descendant)
		end

		weldBuilt(built, handle.CFrame * gripCFrame(tool, key, data, slot))
		local root = built.root
		root.Parent = handle

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = handle
		weld.Parent = root

		root:SetAttribute("MM2VizOverlay", true)

		heldOverlays[tool] = {
			overlay = root,
			hidden = hidden,
			chroma = isChroma(key, data) and startChroma(root) or nil,
			icon = swapToolIcon(tool, iconFor(key, data)),
			skin = key,
			guards = guardVisuals(hidden),
			shot = swapShotSound(tool, key),
		}
	end

	local function myTools(slot)
		local list = {}

		for _, tool in ipairs(CollectionService:GetTagged(slot == "Gun" and "Weapon_Gun" or "Weapon_Knife")) do
			if isMine(tool) then
				list[#list + 1] = tool
			end
		end

		return list
	end

	-- Owned items
	local baseline = {}

	for key, amount in pairs(ProfileData.Weapons.Owned) do
		baseline[key] = amount
	end

	local baselineEquipped = { Knife = ProfileData.Weapons.Equipped.Knife, Gun = ProfileData.Weapons.Equipped.Gun }

	local function spawnItem(key, amount)
		local owned = ProfileData.Weapons.Owned
		owned[key] = (owned[key] or 0) + (amount or 1)

		pcall(function()
			inventoryChanged:Fire("Weapons", key, owned[key])
		end)
	end

	local function despawnAll()
		local owned = ProfileData.Weapons.Owned
		local reverted = 0

		for key in pairs(catalog) do
			if owned[key] ~= baseline[key] then
				owned[key] = baseline[key]

				pcall(function()
					inventoryChanged:Fire("Weapons", key, owned[key] or 0)
				end)

				reverted += 1
			end
		end

		for _, slot in ipairs({ "Knife", "Gun" }) do
			local equipped = ProfileData.Weapons.Equipped[slot]

			if equipped and owned[equipped] == nil then
				local fallback = baselineEquipped[slot]

				if not (fallback and owned[fallback]) then
					fallback = nil

					for key in pairs(owned) do
						local entry = weapons[key]

						if type(entry) == "table" and entry.ItemType == slot then
							fallback = key
							break
						end
					end
				end

				fallback = fallback or (slot == "Knife" and "DefaultKnife" or "DefaultGun")
				ProfileData.Weapons.Equipped[slot] = fallback

				pcall(function()
					EquipService.EquippedChanged:Fire(slot, fallback)
				end)
			end
		end

		return reverted
	end

	-- Catalog for the UI
	local list = {}

	for key in pairs(catalog) do
		local entry = weapons[key]

		list[#list + 1] = {
			key = key,
			name = entry.ItemName or key,
			type = entry.ItemType,
			rarity = entry.Rarity,
			chroma = isChroma(key, catalog[key]),
		}
	end

	local RARITY_ORDER = { Ancient = 1, Godly = 2 }

	table.sort(list, function(a, b)
		local ra, rb = RARITY_ORDER[a.rarity] or 3, RARITY_ORDER[b.rarity] or 3

		if ra ~= rb then
			return ra < rb
		end

		return a.name:lower() < b.name:lower()
	end)

	local function gridImage(key)
		local entry = weapons[key]

		if entry then
			local image = type(entry.Image) == "string" and entry.Image or nil

			if image and (image:find("rbxassetid") or image:find("rbxthumb")) then
				return image
			end

			if image then
				local id = image:match("[Aa]sset[Ii][Dd]=(%d+)") or image:match("[?&]id=(%d+)")

				if id then
					return "rbxthumb://type=Asset&w=150&h=150&id=" .. id
				end
			end

			if tonumber(entry.ItemID) then
				return ("rbxthumb://type=Asset&w=150&h=150&id=%s"):format(tostring(entry.ItemID))
			end
		end

		return iconFor(key, catalog[key]) or ""
	end

	for _, item in ipairs(list) do
		item.image = gridImage(item.key)
	end

	-- Watchers
	local lastEquipped = { Knife = ProfileData.Weapons.Equipped.Knife, Gun = ProfileData.Weapons.Equipped.Gun }

	task.spawn(function()
		for _, slot in ipairs({ "Knife", "Gun" }) do
			local key = ProfileData.Weapons.Equipped[slot]

			if key then
				task.spawn(applyDisplay, slot, key)
			end
		end

		while Skins.alive do
			for _, slot in ipairs({ "Knife", "Gun" }) do
				local key = nil

				pcall(function()
					key = ProfileData.Weapons.Equipped[slot]
				end)

				if key ~= lastEquipped[slot] then
					lastEquipped[slot] = key
					task.spawn(applyDisplay, slot, key)

					for _, tool in ipairs(myTools(slot)) do
						task.spawn(function()
							removeHeld(tool)
							applyHeld(tool, slot)
						end)
					end
				end
			end

			task.wait(0.1)
		end
	end)

	table.insert(conns, EquipService.EquippedChanged.Event:Connect(function(slot, key)
		if slot == "Knife" or slot == "Gun" then
			lastEquipped[slot] = key
			task.spawn(applyDisplay, slot, key)
		end
	end))

	local function watchCharacter(character)
		table.insert(conns, character.ChildAdded:Connect(function(child)
			if child.Name == "DisplayRefKnife" or child.Name == "DisplayRefGun" then
				local slot = child.Name == "DisplayRefKnife" and "Knife" or "Gun"

				task.delay(0.2, function()
					local key = displayOverlays[slot] and displayKeys[slot]

					if key then
						displayOverlays[slot] = nil
						applyDisplay(slot, key)
					end
				end)
			end
		end))
	end

	if localPlayer.Character then
		watchCharacter(localPlayer.Character)
	end

	table.insert(conns, localPlayer.CharacterAdded:Connect(function(character)
		for _, slot in ipairs({ "Knife", "Gun" }) do
			local entry = displayOverlays[slot]

			if entry and entry.overlay then
				pcall(function()
					entry.overlay:Destroy()
				end)
			end
		end

		displayOverlays = {}
		watchCharacter(character)

		task.delay(1, function()
			for _, slot in ipairs({ "Knife", "Gun" }) do
				if displayKeys[slot] then
					applyDisplay(slot, displayKeys[slot])
				end
			end
		end)
	end))

	for _, tag in ipairs({ "Weapon_Knife", "Weapon_Gun" }) do
		local slot = tag == "Weapon_Gun" and "Gun" or "Knife"

		for _, tool in ipairs(CollectionService:GetTagged(tag)) do
			if isMine(tool) then
				task.spawn(applyHeld, tool, slot)
			end
		end

		table.insert(conns, CollectionService:GetInstanceAddedSignal(tag):Connect(function(tool)
			if isMine(tool) then
				task.spawn(applyHeld, tool, slot)
			end
		end))

		table.insert(conns, CollectionService:GetInstanceRemovedSignal(tag):Connect(removeHeld))
	end

	-- Thrown knife keeps only the overlay visible
	table.insert(conns, CollectionService:GetInstanceAddedSignal("ThrowingKnife"):Connect(function(knifePart)
		task.spawn(function()
			local visual = knifePart:WaitForChild("KnifeVisual", 5)

			if not visual then
				return
			end

			local overlay = nil

			for _, descendant in ipairs(visual:GetDescendants()) do
				if descendant:GetAttribute("MM2VizOverlay") then
					overlay = descendant
					break
				end
			end

			if not overlay then
				return
			end

			local ignored = {}
			hideVisual(ignored, visual)

			for _, descendant in ipairs(visual:GetDescendants()) do
				if descendant ~= overlay and not descendant:IsDescendantOf(overlay) then
					hideVisual(ignored, descendant)
				end
			end
		end)
	end))

	-- Knives stuck in walls
	local stuck = {}

	local function hasOwnKnife()
		local character = localPlayer.Character

		for _, tool in ipairs(CollectionService:GetTagged("Weapon_Knife")) do
			if tool:IsDescendantOf(localPlayer) or (character and tool:IsDescendantOf(character)) then
				return true
			end
		end

		return false
	end

	local function removeStuck(part)
		local entry = stuck[part]

		if not entry then
			return
		end

		stuck[part] = nil

		if entry.chroma then
			pcall(function()
				entry.chroma:Disconnect()
			end)
		end

		disconnectGuards(entry.guards)

		if entry.overlay then
			pcall(function()
				entry.overlay:Destroy()
			end)
		end
	end

	local function applyStuck(part)
		if stuck[part] or not hasOwnKnife() then
			return
		end

		local key = ProfileData.Weapons.Equipped.Knife
		local data = key and catalog[key]

		if not data then
			return
		end

		stuck[part] = {}
		local built = buildOverlay(data)

		if not built or not built.root or not part.Parent then
			if built and built.root then
				built.root:Destroy()
			end

			stuck[part] = nil
			return
		end

		local hidden = {}
		hideVisual(hidden, part)

		for _, descendant in ipairs(part:GetDescendants()) do
			hideVisual(hidden, descendant)
		end

		weldBuilt(built, part.CFrame * stuckKnifeCFrame(part.Size, data))
		local root = built.root
		root.Parent = part

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = root

		stuck[part] = { overlay = root, chroma = isChroma(key, data) and startChroma(root) or nil, guards = guardVisuals(hidden) }

		part.Destroying:Once(function()
			removeStuck(part)
		end)
	end

	local function checkStuck(child)
		if child:IsA("BasePart") and child.Name == "StuckKnife" then
			task.spawn(applyStuck, child)
		end
	end

	for _, child in ipairs(Workspace:GetChildren()) do
		checkStuck(child)
	end

	table.insert(conns, Workspace.ChildAdded:Connect(checkStuck))

	Skins.list = list
	Skins.count = #list
	Skins.spawn = spawnItem
	Skins.despawnAll = despawnAll

	Skins.destroy = function()
		Skins.alive = false
		disconnectAll(conns)

		for _, slot in ipairs({ "Knife", "Gun" }) do
			pcall(removeDisplay, slot)
		end

		for tool in pairs(heldOverlays) do
			pcall(removeHeld, tool)
		end

		for part in pairs(stuck) do
			pcall(removeStuck, part)
		end
	end

	Skins.ready = true
end

function Skins.init(onDone)
	task.spawn(function()
		local identity = getthreadidentity and getthreadidentity() or nil

		pcall(function()
			if setthreadidentity then
				setthreadidentity(2)
			end
		end)

		local ok, err = pcall(Skins.build)

		if identity and setthreadidentity then
			pcall(setthreadidentity, identity)
		end

		onDone(ok, err)
	end)
end

------------------------------------------------------------------ interface

local function playerNames()
	local names = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			table.insert(names, player.Name)
		end
	end

	return names
end

local tabs = {
	combat = ui.AddTab("Combat"),
	skins = ui.AddTab("Skin Changer"),
	buttons = ui.AddTab("Buttons"),
	esp = ui.AddTab("ESP"),
	fling = ui.AddTab("Fling & TP"),
	farm = ui.AddTab("Autofarm"),
	rewards = ui.AddTab("Boxes & Hook"),
	player = ui.AddTab("Player"),
	visuals = ui.AddTab("Visuals"),
	keybinds = ui.AddTab("Keybinds"),
	settings = ui.AddTab("Settings"),
}

-- Combat
do
	local misc = tabs.combat:AddSection("Misc", 1)

	misc:AddToggle("Auto Grab Gun", false, function(value)
		if value then
			Combat.startAutoGrab()
		else
			Combat.stopAutoGrab()
		end
	end, { flag = "combat_autograb", tooltip = "Picks up the dropped gun for you." })

	misc:AddToggle("Wall Check", false, function(value)
		Combat.wallCheck = value
	end, { flag = "combat_wallcheck", tooltip = "Only act when you can see the target. Covers silent aim, triggerbot and the buttons." })

	misc:AddToggle("Wallbang", false, function(value)
		Combat.wallbang = value
	end, { flag = "combat_wallbang", tooltip = "Shoots through walls. Covers Shoot Murderer, silent aim and triggerbot." })

	local sheriff = tabs.combat:AddSection("Sheriff (gun)", 1)

	els.silentAim = sheriff:AddToggle("Silent Aim", false, function(value)
		Silent.on = value

		if value then
			Silent.start()
		else
			Silent.stop()
		end
	end, { flag = "combat_silentaim", tooltip = "Bends your shots to the murderer when you click. Needs the gun." })

	sheriff:AddToggle("Triggerbot", false, function(value)
		Trigger.enabled = value

		if value then
			Trigger.start()
		else
			Trigger.stop()
		end
	end, { flag = "combat_triggerbot", tooltip = "Fires by itself when the murderer crosses your crosshair." })

	local prediction = tabs.combat:AddSection("Prediction", 1)

	local function formatPrediction(number)
		local text = string.format("%.3f", number)
		text = text:gsub("0+$", "")
		text = text:gsub("%.$", ".0")
		return text
	end

	local function axisInput(title, axis, flag)
		local input = nil

		input = prediction:AddInput(title, formatPrediction(Predict.value[axis]), function(value)
			local number = tonumber(value)

			if not number or number < 0 then
				notify("Prediction", "Enter a number like 0.132", "error")
				input:Set(formatPrediction(Predict.value[axis]), true)
				return
			end

			number = math.floor(number * 1000 + 0.5) / 1000
			Predict.value[axis] = number
			input:Set(formatPrediction(number), true)
		end, "0.132", { flag = flag })
	end

	axisInput("Prediction X", "X", "pred_x")
	axisInput("Prediction Y", "Y", "pred_y")
	axisInput("Prediction Z", "Z", "pred_z")
	prediction:AddLabel("Shared by Silent Aim, Triggerbot and Shoot Murderer. Up to 3 decimals, like 0.132. 0 turns that axis off.", { wrap = true })

	local murderer = tabs.combat:AddSection("Murderer (knife)", 2)

	murderer:AddSlider("Knife Hitbox (OP!)", 1, 200, 1, 0, function(value)
		Hitbox.setMult(value)
	end, { flag = "combat_hitbox", tooltip = "1 is the default hitbox." })

	murderer:AddToggle("Show Hitbox", false, function(value)
		Hitbox.show = value

		if value then
			Hitbox.showBall()
		else
			Hitbox.hideBall()
		end
	end, { flag = "combat_showhitbox" })

	murderer:AddToggle("Silent Throw", false, function(value)
		SilentThrow.on = value

		if value then
			SilentThrow.start()
		else
			SilentThrow.stop()
		end
	end, { flag = "combat_silentthrow", tooltip = "Right click throws the knife at the nearest player." })

	local killTarget = nil

	els.killTarget = murderer:AddDropdown("Target", playerNames(), nil, function(value)
		killTarget = value
	end)

	murderer:AddButton("Kill Target", function()
		Combat.killTarget(killTarget)
	end)

	murderer:AddButton("Kill All", function()
		Combat.killAll()
	end, { danger = true })
end

-- Skin changer
do
	local section = tabs.skins:AddSection("Visual Skin Changer - only you can see this", "full")
	local status = section:AddLabel("Loading skins...", { wrap = true })

	local grid = section:AddGrid({
		cell = 62,
		height = 200,
		placeholder = "Search skins...",
		onSelect = function(item)
			if not Skins.ready then
				notify("Skins", "Still loading, try again in a second.", "error")
				return
			end

			local ok = pcall(Skins.spawn, item.key, 1)

			if ok then
				notify("Check your inventory", item.name .. " was added. Open your inventory and equip it.")
			else
				notify("Failed", "Couldn't add " .. item.name .. ".", "error")
			end
		end,
	})

	section:AddButton("Spawn all visual skins", function()
		if not Skins.ready then
			notify("Skins", "Still loading, try again in a second.", "error")
			return
		end

		for _, item in ipairs(Skins.list) do
			pcall(Skins.spawn, item.key, 1)
		end

		notify("Check your inventory", "Added " .. #Skins.list .. " skins. Open your inventory to equip them.")
	end)

	section:AddButton("Despawn all visual skins", function()
		if Skins.ready then
			pcall(Skins.despawnAll)
			notify("Skins", "Despawned.")
		end
	end)

	Skins.init(function(ok, err)
		if not ok or not Skins.ready then
			warn("[Magma] skin changer: " .. tostring(err))
			status:SetText("Couldn't load skins: " .. tostring(err):sub(1, 140))
			return
		end

		local items = {}

		for _, item in ipairs(Skins.list) do
			items[#items + 1] = {
				key = item.key,
				name = item.name,
				image = item.image,
				color = item.rarity == "Ancient" and Color3.fromRGB(165, 95, 245) or Color3.fromRGB(255, 110, 190),
				tag = item.chroma and "Chroma" or nil,
			}
		end

		grid:SetItems(items)
		status:SetText(("%d skins - tap one to add it, then open your inventory and equip it."):format(#items))
	end)
end

-- Buttons
do
	local settings = tabs.buttons:AddSection("Layout", 1)

	settings:AddToggle("Lock Buttons In Place", false, function(value)
		HUD.locked = value
	end, { flag = "hud_lock", tooltip = "Stops the on-screen buttons moving when you drag them." })

	settings:AddSlider("Button Size", 50, 200, IS_MOBILE and 70 or 100, 0, function(value)
		HUD.scale = value / 100

		for _, part in next, HUD.parts do
			TweenService:Create(part.scale, TweenInfo.new(0.15), { Scale = HUD.scale }):Play()
		end

		HUD.relayout()
	end, { flag = "hud_size", suffix = "%" })

	local main = tabs.buttons:AddSection("On-Screen Buttons", 1)
	local extra = tabs.buttons:AddSection("Extra Buttons", 2)

	local function hudToggle(section, title, name, tooltip)
		section:AddToggle(title, false, function(value)
			if value then
				HUD.create(name)

				if name == "Fly" then
					HUD.setActive("Fly", Move.fly)
				elseif name == "Noclip" then
					HUD.setActive("Noclip", Move.noclip)
				elseif name == "Xray" then
					HUD.setActive("Xray", Xray.on)
				end
			else
				HUD.destroy(name)
			end
		end, { flag = "hud_" .. name, tooltip = tooltip })
	end

	hudToggle(main, "Shoot Murderer", "Shoot", "Shoots the murderer.")
	hudToggle(main, "Grab Gun", "Grab", "Grabs the gun off the floor. It only drops when the sheriff dies.")
	hudToggle(main, "Throw Knife", "Throw", "Throws your knife at the nearest player.")
	hudToggle(main, "Bomb Jump", "Bomb", "Bomb jump with the cooldown on the button.")
	hudToggle(main, "Wall Hop", "WallHop", "Climbs the wall you are standing against.")
	hudToggle(extra, "Kill All (Murderer)", "KillAll", "Stabs every player at once.")
	hudToggle(extra, "Kill Sheriff (Murderer)", "KillSheriff", "Stabs whoever holds the gun.")
	hudToggle(extra, "Free X-Ray", "Xray", "Makes the map see-through.")
	hudToggle(extra, "Fly Button", "Fly", "Same fly as the Player tab.")
	hudToggle(extra, "Noclip Button", "Noclip", "Same noclip as the Player tab.")
end

-- ESP
do
	local main = tabs.esp:AddSection("See Through Walls", 1)

	local function espToggle(title, key, tooltip, flag)
		main:AddToggle(title, false, function(value)
			ESP[key] = value

			if key == "gun" then
				ESP.refreshGun()
			elseif key == "trap" then
				ESP.refreshTraps()
			else
				ESP.sync()
			end
		end, { flag = flag, tooltip = tooltip })
	end

	espToggle("ESP Outline", "outline", "Glowing outline on every player through walls.", "esp_outline")
	espToggle("Full Body ESP", "fill", "Fills the whole body in the role colour.", "esp_fill")
	espToggle("Display Name ESP", "names", "Their display name above their head.", "esp_names")
	espToggle("Dropped Gun ESP", "gun", "Shows the gun on the floor after the sheriff dies.", "esp_gun")
	espToggle("Trap ESP", "trap", "Shows traps other players hid.", "esp_trap")

	local tracers = tabs.esp:AddSection("Tracers & Distance", 2)

	tracers:AddToggle("Tracers", false, function(value)
		Tracers.lines = value
		Tracers.sync()
	end, { flag = "esp_tracers", tooltip = "Line from the bottom of your screen to every player." })

	tracers:AddToggle("Distance", false, function(value)
		Tracers.dist = value
		Tracers.sync()
	end, { flag = "esp_distance", tooltip = "Studs away, written under their feet." })

	tracers:AddToggle("Off-Screen Arrows", false, function(value)
		Tracers.arrows = value
		Tracers.sync()
	end, { flag = "esp_arrows", tooltip = "Arrows pointing at players you cannot see, including ones behind you." })

	local colors = tabs.esp:AddSection("ESP Colours", 2)

	local function recolor()
		if ESP.active() then
			ESP.refreshPlayers()
		end
	end

	colors:AddColor("Innocent", ESP.colors.innocent, function(color)
		ESP.colors.innocent = color
		recolor()
	end, { flag = "esp_color_innocent" })

	colors:AddColor("Sheriff", ESP.colors.sheriff, function(color)
		ESP.colors.sheriff = color
		recolor()
	end, { flag = "esp_color_sheriff" })

	colors:AddColor("Murderer", ESP.colors.murderer, function(color)
		ESP.colors.murderer = color
		recolor()
	end, { flag = "esp_color_murderer" })

	colors:AddColor("Dropped Gun", ESP.colors.gun, function(color)
		ESP.colors.gun = color
		ESP.refreshGun()
	end, { flag = "esp_color_gun" })

	colors:AddColor("Traps", ESP.colors.trap, function(color)
		ESP.colors.trap = color
		ESP.refreshTraps()
	end, { flag = "esp_color_trap" })
end

-- Fling & teleport
do
	local quick = tabs.fling:AddSection("Quick Actions", 1)

	quick:AddButton("Fling Murderer", function()
		local murderer = getMurderer()

		if not murderer then
			notify("Error!", "No murderer this round!", "error")
		elseif murderer == localPlayer then
			notify("Error!", "You can't fling yourself!", "error")
		else
			Fling.run(murderer)
		end
	end)

	quick:AddButton("Fling Sheriff", function()
		local sheriff = getSheriff()

		if not sheriff then
			notify("Error!", "No sheriff this round!", "error")
		elseif sheriff == localPlayer then
			notify("Error!", "You can't fling yourself!", "error")
		else
			Fling.run(sheriff)
		end
	end)

	quick:AddButton("Fling All", function()
		Fling.runAll()
	end)

	quick:AddButton("Teleport to Murderer", function()
		teleportTo(getMurderer(), "Murderer")
	end)

	quick:AddButton("Teleport to Sheriff", function()
		teleportTo(getSheriff(), "Sheriff")
	end)

	local target = tabs.fling:AddSection("Target Player", 2)

	els.flingTarget = target:AddDropdown("Target", playerNames(), nil, function(value)
		Fling.target = value
	end)

	local function pickTarget()
		if not Fling.target then
			notify("Error!", "Pick a player first!", "error")
			return nil
		end

		local player = Players:FindFirstChild(Fling.target)

		if not player then
			notify("Error!", "Player left the game!", "error")
			return nil
		end

		return player
	end

	target:AddButton("Fling Player", function()
		local player = pickTarget()

		if player then
			Fling.run(player)
		end
	end)

	target:AddButton("Teleport", function()
		local player = pickTarget()

		if player then
			teleportTo(player, player.Name)
		end
	end)

	els.spamFling = target:AddToggle("Spam Fling", false, function(value)
		Fling.spam = value

		if value then
			if not Fling.target then
				notify("Error!", "Pick a player from the dropdown first!", "error")
				Fling.spam = false
				els.spamFling:Set(false, true)
				return
			end

			Fling.startSpam()
			notify("Spam Fling ON", "Spam flinging " .. Fling.target .. "!")
		else
			notify("Spam Fling OFF", "Stopped spam flinging.")
		end
	end)

	local function refreshPlayers()
		local names = playerNames()
		els.flingTarget:SetValues(names)
		els.killTarget:SetValues(names)
	end

	track(Players.PlayerAdded:Connect(refreshPlayers))
	track(Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end))
end

-- Autofarm
do
	local main = tabs.farm:AddSection("Coin Autofarm", 1)

	main:AddToggle("Coin Autofarm", false, function(value)
		Farm.on = value

		if value then
			if Move.fly and els.fly then
				els.fly:Set(false)
			end

			Farm.start()
			Server.startWatch(function()
				return Farm.on and Farm.hopWhenDead
			end)
			notify("Autofarm Started!", "Farming coins!")
		else
			Farm.stop()
			Server.stopWatch()
			notify("Autofarm Stopped!", "Stopped farming.")
		end
	end, { flag = "farm_enabled", tooltip = "Flies you around picking up coins." })

	main:AddSlider("Farm Speed", 5, 25, 25, 0, function(value)
		Farm.speed = value >= 25 and 23 or value
	end, { flag = "farm_speed", tooltip = "Studs per second." })

	local options = tabs.farm:AddSection("Settings", 2)

	els.hopDead = options:AddToggle("Hop When Server Dies", false, function(value)
		Farm.hopWhenDead = value
	end, { flag = "farm_hop", tooltip = "Hops to a fresh server when this one empties out mid-farm." })

	els.antiAfk = options:AddToggle("Anti-AFK", false, function(value)
		Farm.antiAfk = value

		if value then
			Farm.startAntiAfk()
			notify("Anti-AFK Enabled!", "You can go AFK now!")
		else
			Farm.stopAntiAfk()
			notify("Anti-AFK Disabled!", "AFK protection off.")
		end
	end, { flag = "farm_antiafk" })

	els.autoReset = options:AddToggle("Auto-Reset When Bag Full", false, function(value)
		Farm.autoReset = value

		if value then
			Farm.startAutoReset()
		end
	end, { flag = "farm_autoreset", tooltip = "Resets you once your coin bag is full." })

	options:AddToggle("Fling Murderer When Done", false, function(value)
		Farm.flingWhenDone = value
		Farm.flingFired = false
	end, { flag = "farm_flingdone", tooltip = "Flings the murderer once your bag is full or the coins run out." })

	options:AddToggle("Kill All When Bag Full", false, function(value)
		Farm.killWhenFull = value
		Farm.killFired = false
	end, { flag = "farm_killfull", tooltip = "Stabs everyone once your bag fills up. Murderer only." })
end

-- Boxes & webhook
do
	local rewards = tabs.rewards:AddSection("Rewards", 1)

	rewards:AddToggle("Auto Claim Shells", false, function(value)
		Shells.on = value

		if value then
			Shells.start()
			notify("Auto Claim Shells On!", "Rewards claim themselves.")
		else
			notify("Auto Claim Shells Off!", "Claim them yourself.")
		end
	end, { flag = "rewards_shells", tooltip = "Claims the end-of-round reward popup for you." })

	local hook = tabs.rewards:AddSection("Discord Webhook", 1)

	hook:AddInput("Webhook URL", "", function(value)
		if tostring(value) ~= tostring(WH.url) then
			WH.saidHello = false
			WH.broken = false
		end

		WH.url = tostring(value or "")
	end, "https://discord.com/api/webhooks/...", { flag = "wh_url" })

	els.whOn = hook:AddToggle("Start Sender", false, function(value)
		WH.on = value

		if not value then
			return
		end

		task.spawn(function()
			local ok, code = WH.hello()

			notify(ok and "Sender Started" or "Sender Failed", ok and "Posted the opening message to your webhook." or ("Could not post: " .. tostring(code) .. "."), (not ok) and "error" or nil)

			if not ok then
				WH.on = false
				els.whOn:Set(false, true)
			end
		end)
	end, { flag = "wh_on", tooltip = "Logs box opens, shell claims and the coins each round paid out." })

	local boxes = tabs.rewards:AddSection("Auto Open Boxes", 2)
	els.box = {}

	for _, box in ipairs(Boxes.LIST) do
		local key, title = box[1], box[2]
		local currency, price = Boxes.price(key)

		els.box[key] = boxes:AddToggle("Auto Open " .. title, false, function(value)
			Boxes.on[key] = value

			if value then
				Boxes.start(key, title)
			end
		end, {
			flag = "box_" .. key:gsub("%W", "_"),
			tooltip = "Waits until you have " .. (price and comma(price) or "?") .. " " .. (Boxes.NAMES[currency] or currency) .. ", then opens it.",
		})
	end
end

-- Player
do
	local speeds = tabs.player:AddSection("Speeds", 1)

	speeds:AddSlider("Walk Speed", 16, 100, 16, 0, function(value)
		Move.setWalkSpeed(value)
	end, { flag = "player_walkspeed" })

	speeds:AddSlider("Jump Power", 50, 200, 50, 0, function(value)
		Move.setJumpPower(value)
	end, { flag = "player_jumppower" })

	speeds:AddSlider("Fly Speed", 10, 200, 50, 0, function(value)
		Move.flySpeed = value
	end, { flag = "player_flyspeed" })

	local defense = tabs.player:AddSection("Movement & Defense", 2)

	els.antiFling = defense:AddToggle("Anti-Fling", false, function(value)
		Move.antiFling = value

		if value then
			Move.startAntiFling()
			notify("Anti-Fling ON", "Fling protection on!")
		else
			Move.stopAntiFling()
			notify("Anti-Fling OFF", "Fling protection off.")
		end
	end, { flag = "player_antifling", tooltip = "Blocks other players from flinging you." })

	els.noclip = defense:AddToggle("Noclip", false, function(value)
		Move.noclip = value

		if value then
			Move.startNoclip()
		else
			Move.stopNoclip()
		end

		HUD.setActive("Noclip", value)
	end, { flag = "player_noclip", tooltip = "Walk through walls." })

	els.infJump = defense:AddToggle("Infinite Jump", false, function(value)
		Move.infJump = value

		if value then
			Move.startInfJump()
		else
			Move.stopInfJump()
		end
	end, { flag = "player_infjump", tooltip = "Jump as many times as you want mid-air." })

	els.fly = defense:AddToggle("Fly", false, function(value)
		Move.fly = value

		if value then
			Move.startFly()
		else
			Move.stopFly()
		end

		HUD.setActive("Fly", value)
	end, { flag = "player_fly", tooltip = "WASD + Space / LeftShift." })

	local beta = tabs.player:AddSection("Beta", 2)

	beta:AddButton("God Mode [BETA]", function()
		God.start()
	end)

	beta:AddLabel("Nothing can kill you, but you cannot pick up coins or the gun. Needs a round in progress.", { wrap = true })
end

-- Visuals
do
	local sounds = tabs.visuals:AddSection("Sound Changer", 1)

	sounds:AddToggle("Error Sound", true, function(value)
		sfxOn.error = value
	end, { flag = "sfx_error", tooltip = "A cue when something fails or gets refused." })

	sounds:AddToggle("Gun Drop Sound", true, function(value)
		sfxOn.gun = value
	end, { flag = "sfx_gun", tooltip = "A cue when the sheriff dies and the gun drops." })

	sounds:AddToggle("Button Click Sound", true, function(value)
		sfxOn.click = value
	end, { flag = "sfx_click", tooltip = "A click when you press an on-screen button." })

	sounds:AddToggle("Toggle Sound", true, function(value)
		sfxOn.toggle = value
	end, { flag = "sfx_toggle", tooltip = "A click when you flip a switch in the menu." })

	local world = tabs.visuals:AddSection("World", 2)

	els.xray = world:AddToggle("Free X-Ray", false, function(value)
		Xray.set(value)
		HUD.setActive("Xray", value)
	end, { flag = "visuals_xray", tooltip = "Makes the map see-through." })
end

-- Keybinds
local keyActions = {
	Shoot = Combat.shootMurderer,
	Grab = Combat.grabGun,
	Throw = Combat.throwKnife,
	Bomb = Combat.bombJump,
	WallHop = Combat.wallHop,
	Noclip = function()
		toggleElement(els.noclip)
	end,
	Fly = function()
		toggleElement(els.fly)
	end,
	InfJump = function()
		toggleElement(els.infJump)
	end,
	AntiFling = function()
		toggleElement(els.antiFling)
	end,
	Speed = function()
		local humanoid = getHumanoid()
		Move.setWalkSpeed(humanoid and humanoid.WalkSpeed ~= 16 and 16 or Move.sliderSpeed or Move.walkSpeed)
	end,
	Jump = function()
		local humanoid = getHumanoid()
		Move.setJumpPower(humanoid and humanoid.JumpPower ~= 50 and 50 or Move.sliderJump or Move.jumpPower)
	end,
}

local boundKeys = {}

do
	local interface = tabs.keybinds:AddSection("Interface", 1)

	interface:AddKeybind("Toggle GUI", Enum.KeyCode.G, function(key)
		ui.SetMenuKey(key)
	end, { flag = "key_gui" })

	local actions = tabs.keybinds:AddSection("Actions", 1)
	local playerKeys = tabs.keybinds:AddSection("Player", 2)

	local function bindRow(section, title, name)
		section:AddKeybind(title, nil, function(key)
			boundKeys[name] = key
		end, { flag = "key_" .. name })
	end

	bindRow(actions, "Shoot Murderer", "Shoot")
	bindRow(actions, "Grab Gun", "Grab")
	bindRow(actions, "Throw Knife", "Throw")
	bindRow(actions, "Bomb Jump", "Bomb")
	bindRow(actions, "Wall Hop", "WallHop")
	bindRow(playerKeys, "Toggle Noclip", "Noclip")
	bindRow(playerKeys, "Toggle Fly", "Fly")
	bindRow(playerKeys, "Toggle Infinite Jump", "InfJump")
	bindRow(playerKeys, "Toggle Anti-Fling", "AntiFling")
	bindRow(playerKeys, "Toggle Walk Speed", "Speed")
	bindRow(playerKeys, "Toggle Jump Power", "Jump")

	track(UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode == Enum.KeyCode.Unknown then
			return
		end

		if UserInputService:GetFocusedTextBox() then
			return
		end

		for name, key in pairs(boundKeys) do
			if key and input.KeyCode == key and keyActions[name] then
				task.spawn(function()
					pcall(keyActions[name])
				end)
			end
		end
	end))
end

-- Settings
do
	local interface = tabs.settings:AddSection("Interface", 1)

	interface:AddToggle("Show Notifications", true, function(value)
		ui.notificationsEnabled = value
	end, { flag = "ui_notifications" })

	interface:AddToggle("Lock Menu Button", false, function(value)
		ui.SetMenuLocked(value)
	end, { flag = "ui_lockmenu" })

	interface:AddButton("Reset Menu Button Position", function()
		ui.MenuButton.Position = ui.MenuHome
	end)

	local server = tabs.settings:AddSection("Server", 1)

	server:AddButton("Server Hop", function()
		task.spawn(Server.hop)
	end)

	server:AddButton("Smallest Server", function()
		task.spawn(Server.smallest)
	end)

	local config = tabs.settings:AddSection("Config", 2)
	local configName = ""

	els.cfgList = config:AddDropdown("Saved Configs", ui.ListConfigs(), nil, function(value)
		configName = tostring(value or "")
	end)

	els.cfgInput = config:AddInput("Config Name", "", function(value)
		configName = tostring(value or "")
	end, "myconfig")

	local function refreshConfigs()
		els.cfgList:SetValues(ui.ListConfigs())
	end

	local function cleanName()
		local name = configName:gsub("^%s+", ""):gsub("%s+$", "")

		if name == "" then
			notify("Config", "Pick or type a name first.", "error")
			return nil
		end

		if name == "autosave" then
			notify("Config", "That name is reserved for the autosave.", "error")
			return nil
		end

		return name
	end

	config:AddButton("Load Config", function()
		local name = cleanName()

		if name then
			local ok = ui.LoadConfig(name)
			notify(ok and "Config Loaded!" or "Config", ok and ("Loaded " .. name) or "Could not load that config.", (not ok) and "error" or nil)
		end
	end)

	config:AddButton("Save Config", function()
		local name = cleanName()

		if name then
			local ok = ui.SaveConfig(name)
			refreshConfigs()
			notify(ok and "Config Saved!" or "Config", ok and ("Saved as " .. name) or "Could not save.", (not ok) and "error" or nil)
		end
	end)

	config:AddButton("Delete Config", function()
		local name = cleanName()

		if name then
			local ok = ui.DeleteConfig(name)
			refreshConfigs()
			notify(ok and "Config Deleted!" or "Config", ok and (name .. " removed.") or "Could not delete that config.", (not ok) and "error" or nil)
		end
	end)

	config:AddLabel("Everything also autosaves a couple of seconds after you change it and comes back next time you execute.", { wrap = true })

	config:AddButton("Delete Autosave", function()
		Skins.noAutosave = true
		local ok = ui.DeleteConfig("autosave")
		notify(ok and "Autosave Deleted!" or "Config", ok and "Re-execute the script to come up on defaults." or "Nothing to delete.", (not ok) and "error" or nil)
	end)

	local danger = tabs.settings:AddSection("Script", 2)

	danger:AddButton("Unload", function()
		ui.Destroy()
	end, { danger = true })
end

------------------------------------------------------------------ startup / cleanup

ui.onSave = function()
	return { hud = HUD.capture() }
end

ui.onLoad = function(extra)
	if type(extra.hud) == "table" then
		HUD.positions = extra.hud

		for name, part in next, HUD.parts do
			local saved = HUD.positions[name]

			if saved then
				part.button.Position = UDim2.new(saved[1], saved[2], saved[3], saved[4])
			end
		end
	end
end

-- Defaults that should start on.
for _, element in ipairs({ els.hopDead, els.antiAfk, els.autoReset, els.antiFling }) do
	element:Set(true)
end

ui.SelectTab(tabs.combat)
ui.LoadConfig("autosave")
ui.SetMenuVisible(true)
HUD.relayout()

task.delay(1, function()
	booting = false
end)

local function cleanup()
	alive = false
	Skins.noAutosave = true

	pcall(function()
		if Skins.destroy then
			Skins.destroy()
		end
	end)

	Server.stopWatch()
	Combat.stopAutoGrab()
	Silent.stop()
	SilentThrow.stop()
	Predict.setMarker(false)
	Trigger.stop()
	Hitbox.stop()
	Hitbox.hideBall()
	Tracers.stop()
	Farm.on = false
	Farm.stop()
	Farm.stopAntiAfk()
	Farm.autoReset = false
	Shells.on = false
	Fling.active = false
	Fling.spam = false
	Fling.all = false

	for key in pairs(Boxes.on) do
		Boxes.on[key] = false
	end

	Move.fly, Move.noclip, Move.infJump, Move.antiFling = false, false, false, false
	pcall(Move.stopFly)
	pcall(Move.stopNoclip)
	pcall(Move.stopInfJump)
	pcall(Move.stopAntiFling)
	pcall(Move.setWalkSpeed, 16)
	pcall(Move.setJumpPower, 50)

	if Combat.velocityConnection then
		pcall(function()
			Combat.velocityConnection:Disconnect()
		end)
	end

	if Combat.animConnection then
		pcall(function()
			Combat.animConnection:Disconnect()
		end)
	end

	pcall(Xray.set, false)
	pcall(ESP.unreveal)
	ESP.outline, ESP.fill, ESP.names, ESP.gun, ESP.trap = false, false, false, false, false
	ESP.looping = false
	pcall(function()
		ESP.gui:Destroy()
	end)

	HUD.destroyAll()
	disconnectAll(connections)
	_G.MagmaMM2Cleanup = nil
end

ui.OnDestroy(cleanup)
_G.MagmaMM2Cleanup = function()
	ui.Destroy()
end

-- Autosave loop
task.spawn(function()
	task.wait(3)
	local last = ui.Snapshot()

	while alive do
		task.wait(2)

		if not Skins.noAutosave then
			local snapshot = ui.Snapshot()

			if snapshot ~= "" and snapshot ~= last then
				last = snapshot
				ui.SaveConfig("autosave")
			end
		end
	end
end)

notify("Magma", "Loaded. G toggles the window.")

end

xpcall(magmaMain, function(err)
	warn("[Magma] failed to start: " .. tostring(err))
	warn(debug.traceback())
end)
