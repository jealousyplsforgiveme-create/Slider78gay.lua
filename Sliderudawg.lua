if not shared then
	return warn("No shared, no script.")
end

local userInputService = game:GetService("UserInputService")
local textService = game:GetService("TextService")
local tweenService = game:GetService("TweenService")
local workspaceService = game:GetService("Workspace")
local playersService = game:GetService("Players")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local starterGui = game:GetService("StarterGui")
local teamsService = game:GetService("Teams")
local teleportService = game:GetService("TeleportService")
local httpService = game:GetService("HttpService")

local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local SIDEBAR_WIDTH = 90
local HEADER_HEIGHT = 34
local MAX_LIST_ROWS = 6

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

local RENDER_NAME = "MM2Esp"
local RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 4
local COIN_RETRY_SECONDS = 5
local FARM_MAX_SPEED = 30
local MAX_PREDICTION_SPEED = 250
local ROLE_POLL_SECONDS = 1
local FLING_TIMEOUT = 8
local FLING_SUCCESS_SPEED = 300
local CAMLOCK_NAME = "MM2Camlock"
local SILENT_NAME = "MM2Silent"
local NEAREST_PART_NAMES = {
	"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
	"LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot",
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}
local LEGACY_RAY_METHODS = { FindPartOnRay = true, FindPartOnRayWithIgnoreList = true, FindPartOnRayWithWhitelist = true }
local SCREEN_RAY_METHODS = { ViewportPointToRay = true, ScreenPointToRay = true }
local MOUSE_KEYS = { Hit = true, Target = true, UnitRay = true }

local HEALTH_LOW = Color3.fromRGB(255, 60, 60)
local HEALTH_MID = Color3.fromRGB(255, 220, 60)
local HEALTH_HIGH = Color3.fromRGB(70, 220, 90)
local HEALTH_STEPS = 14
local OUTLINE_COLOR = Color3.fromRGB(0, 0, 0)

local function healthColor(t)
	if t < 0.5 then
		return HEALTH_LOW:Lerp(HEALTH_MID, t * 2)
	end

	return HEALTH_MID:Lerp(HEALTH_HIGH, (t - 0.5) * 2)
end

local R15_BONES = {
	{ "Head", "UpperTorso" },
	{ "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" },
	{ "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightLowerArm" },
	{ "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" },
	{ "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightLowerLeg" },
	{ "RightLowerLeg", "RightFoot" },
}

local R6_BONES = {
	{ "Head", "Torso" },
	{ "Torso", "Left Arm" },
	{ "Torso", "Right Arm" },
	{ "Torso", "Left Leg" },
	{ "Torso", "Right Leg" },
}

local PART_GROUPS = {
	Head = { "Head" },
	HumanoidRootPart = { "HumanoidRootPart" },
	Torso = { "UpperTorso", "Torso" },
	Feet = { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" },
	["Left Leg"] = { "LeftLowerLeg", "Left Leg" },
	["Right Leg"] = { "RightLowerLeg", "Right Leg" },
	["Both Legs"] = { "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" },
}

local EXTRA_TEAM_COLORS = {
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(190, 90, 255),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(60, 220, 200),
}

local RENDER_BINDS = { "MagmaTarget", "MagmaCamlock", "MagmaTrigger", "MagmaEsp", "MagmaSpectate" }
local CONFIG_FOLDER = "Magma/Configs"
local AUTOLOAD_FILE = "Magma/autoload.txt"

local showToast = nil

local function notify(content)
	warn("[magma] " .. content)

	if showToast and showToast(content) then
		return
	end

	pcall(function()
		starterGui:SetCore("SendNotification", { Title = "magma", Text = content, Duration = 5 })
	end)
end

local function computeShapes(character, project, settings, healthFraction, tracerOrigin)
	local segments = {}
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")

	if not root or not head then
		return segments, nil
	end

	local left, top, bottom, right = nil, nil, nil, nil
	local wantBounds = settings.boxes or settings.health or settings.tracers or settings.names

	do
		if wantBounds then
			local topPoint = project(head.Position + Vector3.new(0, head.Size.Y / 2 + 0.15, 0))
			local bottomPoint = project(root.Position - Vector3.new(0, 3.1, 0))

			if topPoint and bottomPoint and bottomPoint.Y - topPoint.Y > 2 then
				local height = bottomPoint.Y - topPoint.Y
				local width = height * 0.5
				local centerX = (topPoint.X + bottomPoint.X) / 2

				left = centerX - width / 2
				top = topPoint.Y
				bottom = bottomPoint.Y
				right = centerX + width / 2

				if settings.boxes then
					local corners = {
						{ Vector2.new(left, top), Vector2.new(right, top) },
						{ Vector2.new(left, bottom), Vector2.new(right, bottom) },
						{ Vector2.new(left, top), Vector2.new(left, bottom) },
						{ Vector2.new(right, top), Vector2.new(right, bottom) },
					}

					if settings.outline then
						for _, edge in next, corners do
							table.insert(segments, { edge[1], edge[2], OUTLINE_COLOR, 3 })
						end
					end

					for _, edge in next, corners do
						table.insert(segments, { edge[1], edge[2], settings.color, 1 })
					end
				end
			end
		end

		if settings.skeleton then
			local bones = character:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
			local points = {}

			for _, bone in next, bones do
				for _, name in next, bone do
					if points[name] == nil then
						local part = character:FindFirstChild(name)
						points[name] = part and project(part.Position) or false
					end
				end

				local from = points[bone[1]]
				local to = points[bone[2]]

				if from and to then
					table.insert(segments, { from, to, settings.skeletonColor or settings.color, 1 })
				end
			end
		end
	end

	local bounds = nil

	if left and top and bottom and right then
		bounds = { left = left, top = top, bottom = bottom, right = right }
	end

	if settings.health and healthFraction and bounds then
		local barX = bounds.left - 5
		local height = bounds.bottom - bounds.top

		for step = 0, HEALTH_STEPS - 1 do
			local lower = step / HEALTH_STEPS

			if healthFraction > lower then
				local upper = math.min(healthFraction, (step + 1) / HEALTH_STEPS)
				local from = Vector2.new(barX, bounds.bottom - lower * height)
				local to = Vector2.new(barX, bounds.bottom - upper * height)

				table.insert(segments, { from, to, healthColor((lower + upper) / 2), 2 })
			end
		end
	end

	if settings.tracers and bounds and tracerOrigin then
		local tracerTarget = Vector2.new((bounds.left + bounds.right) / 2, bounds.bottom)
		table.insert(segments, { tracerOrigin, tracerTarget, settings.color, 1 })
	end

	return segments, bounds
end

local GAME_UNIVERSES = { mm2 = 66654135 }

local ICON_SHAPES = {
	plus = { { "bar", 0.5, 0.5, 0.8, 0.18 }, { "bar", 0.5, 0.5, 0.18, 0.8 } },
	chevron = { { "bar", 0.3, 0.5, 0.55, 0.16, 40 }, { "bar", 0.7, 0.5, 0.55, 0.16, -40 } },
}

local function makeIcon(parent, name, color, size, position)
	local holder = make("Frame", {
		Position = position or UDim2.new(),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = parent,
	})

	for _, shape in next, ICON_SHAPES[name] or ICON_SHAPES.plus do
		local kind = shape[1]
		local width = shape[4]
		local height = (kind == "dot" or kind == "ring") and width or shape[5]
		local rotation = 0

		if kind == "bar" or kind == "pill" then
			rotation = shape[6] or 0
		end

		local frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(shape[2], shape[3]),
			Size = UDim2.fromScale(width, height),
			BackgroundColor3 = color,
			BackgroundTransparency = (kind == "ring" or kind == "oval" or shape[7] == true) and 1 or 0,
			BorderSizePixel = 0,
			Rotation = rotation,
			Parent = holder,
		})

		if kind == "dot" or kind == "ring" or kind == "oval" or kind == "pill" then
			round(frame, 999)
		else
			round(frame, 1)
		end

		if kind == "ring" then
			make("UIStroke", { Color = color, Thickness = shape[5], Parent = frame })
		elseif kind == "oval" then
			make("UIStroke", { Color = color, Thickness = shape[6], Parent = frame })
		end
	end

	return holder
end

local function tweenTo(instance, duration, goal, style, direction)
	tweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal):Play()
end

local function makeBaseplateIcon(parent)
	local frame = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	})

	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(104, 166, 232), Color3.fromRGB(214, 234, 250)),
		Rotation = 90,
		Parent = frame,
	})

	local sun = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.78, 0.2),
		Size = UDim2.fromScale(0.16, 0.16),
		BackgroundColor3 = Color3.fromRGB(255, 244, 190),
		BorderSizePixel = 0,
		Parent = frame,
	})

	round(sun, 999)

	local plate = make("Frame", {
		Position = UDim2.fromScale(0, 0.56),
		Size = UDim2.fromScale(1, 0.44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame,
	})

	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(70, 76, 84), Color3.fromRGB(104, 111, 120)),
		Rotation = 90,
		Parent = plate,
	})

	for _, y in next, { 0.2, 0.44, 0.74 } do
		make("Frame", {
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Color3.fromRGB(150, 158, 170),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Parent = plate,
		})
	end

	for _, x in next, { 0.1, 0.3, 0.5, 0.7, 0.9 } do
		make("Frame", {
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Color3.fromRGB(150, 158, 170),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Parent = plate,
		})
	end

	return frame
end

local function makeGameIcon(parent, id, size, position, radius)
	local holder = make("Frame", {
		Position = position or UDim2.new(),
		Size = size,
		BackgroundColor3 = THEME.control,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	})

	round(holder, radius or 10)

	if id == "universal" then
		makeBaseplateIcon(holder)
	else
		textLabel({
			Size = UDim2.fromScale(1, 1),
			Text = "MM2",
			TextColor3 = THEME.accent,
			Font = FONT_BOLD,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = holder,
		})

		local universe = GAME_UNIVERSES[id]

		if universe then
			make("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", universe),
				ScaleType = Enum.ScaleType.Crop,
				Parent = holder,
			})
		end
	end

	return holder
end

local function updateArrow(triangle, camera, position, color)
	if not triangle then
		return
	end

	local point, onScreen = camera:WorldToViewportPoint(position)
	local inFront = point.Z > 0

	if onScreen and inFront then
		triangle.Visible = false
		return
	end

	local center = camera.ViewportSize / 2
	local delta = Vector2.new(point.X, point.Y) - center

	if not inFront then
		delta = -delta
	end

	if delta.Magnitude < 1 then
		delta = Vector2.new(0, -1)
	end

	local direction = delta.Unit
	local radius = math.min(center.X, center.Y) - 36
	local tip = center + direction * radius
	local back = tip - direction * 16
	local side = Vector2.new(-direction.Y, direction.X) * 7

	triangle.PointA = tip
	triangle.PointB = back + side
	triangle.PointC = back - side
	triangle.Color = color
	triangle.Filled = true
	triangle.Visible = true
end

local function createUi(subtitle, gameId)
	local guiParent = gethui and gethui() or game:GetService("CoreGui")
	local camera = workspaceService.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(800, 400)
	local windowWidth = math.min(520, viewport.X - 40)
	local windowHeight = math.min(300, viewport.Y - 40)

	local connections = {}
	local binds = {}
	local keybindRegistry = {}
	local activeDrag = nil
	local activeEnd = nil
	local listeningBind = nil
	local openPopup = nil
	local tooltipToken = 0
	local menuKey = Enum.KeyCode.RightShift
	local menuLocked = false

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

	local SIDEBAR_W = 104

	make("Frame", {
		Position = UDim2.fromOffset(SIDEBAR_W, 46),
		Size = UDim2.new(0, 1, 1, -58),
		BackgroundColor3 = THEME.line,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = window,
	})

	local sidebar = make("Frame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(0, SIDEBAR_W, 1, -56),
		BackgroundTransparency = 1,
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

	local function makeGear(parent, position, callback)
		local button = make("TextButton", {
			Size = UDim2.fromOffset(14, 14),
			Position = position,
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 3,
			Parent = parent,
		})

		local ring = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			BackgroundTransparency = 1,
			Parent = button,
		})

		round(ring, 999)
		make("UIStroke", { Color = THEME.text, Thickness = 2, Parent = ring })

		if callback then
			table.insert(connections, button.Activated:Connect(callback))
		end

		return button
	end

	local function addTooltipMark(row, label, text, tip)
		if not tip then
			return
		end

		local width = textService:GetTextSize(text, 11, FONT, Vector2.new(1000, 100)).X

		local mark = make("TextButton", {
			Position = UDim2.new(0, label.Position.X.Offset + width + 5, 0, 0),
			Size = UDim2.fromOffset(12, 14),
			BackgroundTransparency = 1,
			Text = "?",
			TextColor3 = THEME.accentLight,
			TextSize = 10,
			Font = FONT_BOLD,
			ZIndex = 3,
			Parent = row,
		})

		table.insert(connections, mark.Activated:Connect(function()
			showTooltip(mark, tip)
		end))
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

		refresh()

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

		if options.gear then
			makeGear(row, UDim2.new(1, -14, 0, 1), options.gear)
		end

		return {
			SetText = function(_, value)
				label.Text = value
			end,
		}
	end

	function Section:AddButton(text, callback)
		local danger = text == "Unload"
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
			table.insert(connections, button.Activated:Connect(callback))
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
			self.Value = value

			boxGradient.Color = value and ColorSequence.new(THEME.accentLight, THEME.accent) or ColorSequence.new(Color3.fromRGB(38, 38, 45), Color3.fromRGB(26, 26, 31))
			boxStroke.Color = value and THEME.accent or THEME.line
			label.TextColor3 = value and THEME.textBright or THEME.text

			tweenTo(knob, 0.16, {
				Position = UDim2.new(0, value and 15 or 2, 0.5, 0),
				BackgroundColor3 = value and Color3.new(1, 1, 1) or THEME.text,
			}, Enum.EasingStyle.Back)

			tweenTo(glowOuter, 0.2, { BackgroundTransparency = value and 0.9 or 1 })
			tweenTo(glowInner, 0.2, { BackgroundTransparency = value and 0.74 or 1 })

			if not silent and self.Callback then
				task.spawn(self.Callback, value)
			end
		end

		function toggle:AddKeybind(default)
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
			table.insert(keybindRegistry, { label = text .. " Key", bind = bind })

			table.insert(connections, keyButton.Activated:Connect(function()
				listeningBind = bind
				keyButton.Text = "..."
			end))

			if default then
				bind:Set(default)
			end

			return self
		end

		function toggle:AddColor(default, onChange)
			local color = default or THEME.accent

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

			return self
		end

		table.insert(connections, button.Activated:Connect(function()
			toggle:Set(not toggle.Value)
		end))

		toggle:Set(toggle.Value, true)

		return toggle
	end

	function Section:AddSlider(text, minimum, maximum, default, rounding, callback, options)
		options = options or {}

		local slider = { Value = default, Callback = callback }
		local row = newRow(self, 32)
		local trackInset = options.gear and 18 or 0

		local label = textLabel({
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -70, 0, 16),
			Text = text,
			TextColor3 = THEME.textBright,
			Parent = row,
		})

		local chip = make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -trackInset - 2, 0, 0),
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
			Size = UDim2.new(1, -8 - trackInset, 0, 5),
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

		make("UIGradient", {
			Color = ColorSequence.new(THEME.accentDark, THEME.accentLight),
			Parent = fill,
		})

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
			Size = UDim2.new(1, -trackInset, 0, 18),
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

		if options.gear then
			makeGear(row, UDim2.new(1, -14, 0, 16), options.gear)
		end

		slider:Set(default, true)

		return slider
	end

	function Section:AddDropdown(text, values, default, callback, options)
		options = options or {}

		local multi = options.multi == true
		local dropdown = { Callback = callback, Values = values }
		local row = newRow(self, 40)
		local boxInset = options.gear and 18 or 0

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

		local box, boxStroke = controlBox(row, UDim2.fromOffset(0, 18), UDim2.new(1, -boxInset, 0, 21))

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

			if self.Callback then
				task.spawn(self.Callback, self.Value)
			end
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

		if options.gear then
			makeGear(row, UDim2.new(1, -14, 0, 21), options.gear)
		end

		dropdown:Set(dropdown.Value, true)

		return dropdown
	end

	function Section:AddInput(text, default, callback, placeholder)
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
			self.Value = tostring(value)
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

		return input
	end

	function Section:AddColor(text, default, callback)
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

		local object = { Value = color, Swatch = swatch }

		function object:Set(newColor, silent)
			color = newColor
			self.Value = newColor
			swatch.BackgroundColor3 = newColor

			if not silent and callback then
				callback(newColor)
			end
		end

		return object
	end

	function Section:AddKeybind(text, default, callback)
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

		keyButton.Text = bind.Describe(default)
		table.insert(keybindRegistry, { label = text, bind = bind })

		return bind
	end

	local Tab = {}
	Tab.__index = Tab

	function Tab:AddSection(name, column)
		local holderColumn = self.columns[column or 1]

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

	local tabs = {}

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

		local columnsHolder = make("Frame", {
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = tab.content,
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

			make("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = column,
			})

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
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
				bind:Set(input.UserInputType)
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

	showToast = function(text)
		if not toastHolder.Parent then
			return false
		end

		toastOrder += 1

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

	local ui = {
		gui = gui,
		window = window,
		tabs = tabs,
		connections = connections,
		addTab = addTab,
		selectTab = selectTab,
		setMenuVisible = setMenuVisible,
		menuButton = menuButton,
		menuHome = menuButton.Position,
		keybindRegistry = keybindRegistry,
		setMenuKey = function(key)
			menuKey = key
		end,
		setMenuLocked = function(value)
			menuLocked = value
		end,
		getMenuLocked = function()
			return menuLocked
		end,
	}

	function ui.destroy()
		for _, connection in next, connections do
			connection:Disconnect()
		end

		if blur then
			blur:Destroy()
			blur = nil
		end

		gui:Destroy()
	end

	return ui
end

local FovVisual = {}
FovVisual.__index = FovVisual

function FovVisual.new()
	local self = setmetatable({ objects = {} }, FovVisual)

	local function newCircle(filled, thickness, zIndex)
		local circle = Drawing.new("Circle")
		circle.Filled = filled
		circle.Thickness = thickness
		circle.NumSides = 90
		circle.ZIndex = zIndex
		circle.Visible = false
		table.insert(self.objects, circle)

		return circle
	end

	self.base = newCircle(true, 1, 1)
	self.ring = newCircle(false, 1, 2)

	return self
end

function FovVisual:hide()
	for _, object in next, self.objects do
		object.Visible = false
	end
end

function FovVisual:destroy()
	for _, object in next, self.objects do
		pcall(function()
			object:Remove()
		end)
	end

	self.objects = {}
end

function FovVisual:update(visible, center, radius, color, filled, opacity, rainbow)
	if not visible then
		self:hide()
		return
	end

	if rainbow then
		color = Color3.fromHSV((os.clock() * 0.2) % 1, 0.8, 1)
	end

	local ring = self.ring
	ring.Position = center
	ring.Radius = radius
	ring.Color = color
	ring.Transparency = 1
	ring.Visible = true

	local base = self.base
	base.Visible = filled

	if filled then
		base.Position = center
		base.Radius = radius
		base.Color = color
		base.Transparency = opacity
	end
end

local function buildMenuTab(ui, tab, cleanup)
	local menuSection = tab:AddSection("Menu", 1)

	menuSection:AddKeybind("Menu Keybind", Enum.KeyCode.RightShift, function(key)
		ui.setMenuKey(key)
	end)

	menuSection:AddToggle("Lock Menu Button", false, function(value)
		ui.setMenuLocked(value)
	end)

	menuSection:AddButton("Reset Button Position", function()
		ui.menuButton.Position = ui.menuHome
	end)

	menuSection:AddButton("Hide Menu", function()
		ui.setMenuVisible(false)
	end)

	local actionSection = tab:AddSection("Actions", 2)

	actionSection:AddButton("Unload", function()
		cleanup()
	end)
end

local function runMM2()
	local ui = createUi("mm2", "mm2")
	local gui = ui.gui
	local connections = ui.connections
	local addTab = ui.addTab
	local selectTab = ui.selectTab
	local tabs = ui.tabs
	local setMenuVisible = ui.setMenuVisible
	local menuButton = ui.menuButton

	local localPlayer = playersService.LocalPlayer
	local alive = true
	local performanceActive = false

	-- Declared up front so cleanup() can reach them regardless of definition order.
	local setAntiAfk, stopFly
	local noclipParts = {}

	local Config = {
		autoFarm = false,
		farmSpeed = 20,
		farmAvoid = true,
		farmAvoidDistance = 35,
		flingReturn = true,
		flingRadius = 2,
		flingSpeed = 18,
		camlock = false,
		camlockSmoothing = 0.25,
		camlockPart = "Head",
		camlockWallCheck = false,
		camlockFov = false,
		camlockFovRadius = 150,
		camlockFovShow = false,
		camlockFovColor = Color3.fromRGB(255, 255, 255),
		camlockPrediction = false,
		predX = 0.13,
		predY = 0.13,
		predZ = 0.13,
		silentAim = false,
		silentPart = "Head",
		silentWallCheck = false,
		silentPrediction = false,
		silentDebug = false,
		silentInnocentCheck = true,
		silentUseFov = true,
		silentFovRadius = 150,
		silentFovShow = false,
		silentFovFilled = false,
		silentFovColor = Color3.fromRGB(255, 60, 60),
		camlockFovFilled = false,
		fovOpacity = 0.15,
		fovRainbow = false,
		wallCheckDebug = false,
		roleAlerts = true,
		autoEquip = false,
		proximityDistance = 60,
		proximityCooldown = 8,
		showWatermark = false,
		antiAfk = false,
		performanceMode = false,
		performanceAuto = true,
		performanceThreshold = 30,
		noclip = false,
		fly = false,
		flySpeed = 60,
		infiniteJump = false,
		walkSpeedEnabled = false,
		walkSpeedValue = 32,
		murdererArrow = false,
		grabButton = true,
		lockMenuButton = false,
		killReturn = true,
		tpDistance = 4,
		tpReturn = true,
		shootInput = "Activate",
		esp = false,
		espBoxes = true,
		espOutline = true,
		espNames = true,
		espSkeleton = false,
		espTracers = false,
		espHealth = false,
		showInnocents = true,
		espMaxDistance = 2000,
		murdererColor = Color3.fromRGB(255, 60, 60),
		sheriffColor = Color3.fromRGB(80, 160, 255),
		heroColor = Color3.fromRGB(255, 220, 60),
		innocentColor = Color3.fromRGB(70, 220, 90),
		skinChanger = false,
		knifeSkin = "None",
		gunSkin = "None",
	}

	local Maid = {}
	Maid.__index = Maid

	function Maid.new()
		return setmetatable({ tasks = {} }, Maid)
	end

	function Maid:add(item)
		table.insert(self.tasks, item)
		return item
	end

	function Maid:clean()
		local tasks = self.tasks
		self.tasks = {}

		for index = #tasks, 1, -1 do
			local item = tasks[index]
			local itemType = typeof(item)

			if itemType == "function" then
				pcall(item)
			elseif itemType == "RBXScriptConnection" then
				item:Disconnect()
			elseif itemType == "Instance" then
				item:Destroy()
			else
				local success, remover = pcall(function()
					return item.destroy or item.Remove or item.Destroy
				end)

				if success and remover then
					pcall(remover, item)
				end
			end
		end
	end

	local maid = Maid.new()

	local function safe(label, callback, ...)
		local success, message = pcall(callback, ...)

		if not success then
			notify(string.format("%s failed: %s", label, tostring(message)))
		end

		return success
	end

	local function protect(label, callback)
		local lastMessage = nil

		return function(...)
			local success, message = pcall(callback, ...)

			if success or message == lastMessage then
				return
			end

			lastMessage = message
			notify(string.format("%s error: %s", label, tostring(message)))
		end
	end

	local drawingSupported = pcall(function()
		Drawing.new("Line"):Remove()
	end)

	local Roles = { data = {}, remote = nil }
	local lastSelfRole = nil
	local lastProximityAlert = 0
	local onRolesUpdated = nil
	local autoEquipFor = nil

	local function playAlertSound()
		pcall(function()
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
			sound.Volume = 0.6
			sound.Parent = game:GetService("SoundService")
			sound:Play()
			game:GetService("Debris"):AddItem(sound, 2)
		end)
	end

	local function findRemote(name)
		local remotes = replicatedStorage:FindFirstChild("Remotes")
		return (remotes and remotes:FindFirstChild(name, true)) or replicatedStorage:FindFirstChild(name, true)
	end

	local function pollRoles()
		local remote = Roles.remote

		if not remote or not remote.Parent then
			remote = findRemote("GetPlayerData")
			Roles.remote = remote
		end

		if not remote or not remote:IsA("RemoteFunction") then
			return
		end

		local success, data = pcall(remote.InvokeServer, remote)

		if success and type(data) == "table" then
			Roles.data = data

			if onRolesUpdated then
				onRolesUpdated()
			end
		end
	end

	safe("Role updates", function()
		local changed = findRemote("PlayerDataChanged")

		if changed and changed:IsA("RemoteEvent") then
			maid:add(changed.OnClientEvent:Connect(function(data)
				if type(data) == "table" then
					Roles.data = data

					if onRolesUpdated then
						onRolesUpdated()
					end
				end
			end))
		end

		task.spawn(function()
			while alive do
				pcall(pollRoles)
				task.wait(ROLE_POLL_SECONDS)
			end
		end)
	end)

	local function getRole(player)
		local entry = Roles.data[player.Name]
		local role = type(entry) == "table" and entry.Role or nil

		if type(role) == "string" and role ~= "" then
			return role
		end

		local character = player.Character

		local backpack = player:FindFirstChildOfClass("Backpack")

		if character and character:FindFirstChild("Knife") or backpack and backpack:FindFirstChild("Knife") then
			return "Murderer"
		end

		if character and character:FindFirstChild("Gun") or backpack and backpack:FindFirstChild("Gun") then
			return "Sheriff"
		end

		return "Innocent"
	end

	local function findPlayerWithRole(role)
		for _, player in next, playersService:GetPlayers() do
			if player ~= localPlayer and getRole(player) == role then
				return player
			end
		end

		return nil
	end

	local function roleColor(role)
		if role == "Murderer" then
			return Config.murdererColor
		end

		if role == "Sheriff" then
			return Config.sheriffColor
		end

		if role == "Hero" then
			return Config.heroColor
		end

		return Config.innocentColor
	end

	local camlockParams = RaycastParams.new()
	camlockParams.FilterType = Enum.RaycastFilterType.Exclude
	camlockParams.IgnoreWater = true

	local function getHeldTool()
		local character = localPlayer.Character

		if not character then
			return nil
		end

		for _, child in next, character:GetChildren() do
			if child:IsA("Tool") then
				return child.Name
			end
		end

		return nil
	end

	local getNearestPart = nil

	local function getAimPart(character, partName)
		local name = partName or Config.camlockPart

		if name == "Nearest" and getNearestPart then
			return getNearestPart(character)
		end

		if name == "Head" then
			local head = character:FindFirstChild("Head")

			if head then
				return head
			end
		end

		return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	end

	local function getAliveCharacter(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not humanoid or humanoid.Health <= 0 then
			return nil
		end

		return character
	end

	local wallDebugLine = nil
	local murdererArrowTriangle = nil

	if drawingSupported then
		wallDebugLine = maid:add(Drawing.new("Line"))
		wallDebugLine.Thickness = 2
		wallDebugLine.Visible = false

		murdererArrowTriangle = maid:add(Drawing.new("Triangle"))
		murdererArrowTriangle.Thickness = 1
		murdererArrowTriangle.Visible = false
	end

	local function isVisible(camera, part, character)
		local origin = camera.CFrame.Position
		local result = workspaceService:Raycast(origin, part.Position - origin, camlockParams)
		local clear = result == nil or result.Instance:IsDescendantOf(character)

		if Config.wallCheckDebug and wallDebugLine then
			local point = camera:WorldToViewportPoint(part.Position)

			wallDebugLine.From = camera.ViewportSize / 2
			wallDebugLine.To = Vector2.new(point.X, point.Y)
			wallDebugLine.Color = clear and Color3.fromRGB(70, 220, 90) or Color3.fromRGB(255, 60, 60)
			wallDebugLine.Visible = point.Z > 0
		end

		return clear
	end

	getNearestPart = function(character)
		local camera = workspaceService.CurrentCamera
		local root = character:FindFirstChild("HumanoidRootPart")

		if not camera then
			return root
		end

		local center = camera.ViewportSize / 2
		local candidates = {}
		local allVisible = true

		for _, name in next, NEAREST_PART_NAMES do
			local part = character:FindFirstChild(name)

			if part and part:IsA("BasePart") then
				local point = camera:WorldToViewportPoint(part.Position)
				local visible = isVisible(camera, part, character)

				if not visible then
					allVisible = false
				end

				table.insert(candidates, {
					part = part,
					name = name,
					visible = visible,
					distance = point.Z > 0 and (Vector2.new(point.X, point.Y) - center).Magnitude or math.huge,
				})
			end
		end

		if #candidates == 0 then
			return root
		end

		local best = nil

		for _, candidate in next, candidates do
			local eligible = candidate.visible

			if allVisible then
				eligible = candidate.name == "Head" or candidate.name == "UpperTorso" or candidate.name == "Torso"
			end

			if eligible and (not best or candidate.distance < best.distance) then
				best = candidate
			end
		end

		if not best then
			for _, candidate in next, candidates do
				if not best or candidate.distance < best.distance then
					best = candidate
				end
			end
		end

		return best.part
	end


	local function predictPosition(part, enabled)
		local position = part.Position

		if not enabled then
			return position
		end

		local velocity = part.AssemblyLinearVelocity

		if velocity.Magnitude > MAX_PREDICTION_SPEED then
			velocity = velocity.Unit * MAX_PREDICTION_SPEED
		end

		return position + Vector3.new(velocity.X * Config.predX, velocity.Y * Config.predY, velocity.Z * Config.predZ)
	end

	local function inFov(camera, position, radius)
		local point, onScreen = camera:WorldToViewportPoint(position)

		if not onScreen then
			return false
		end

		return (Vector2.new(point.X, point.Y) - camera.ViewportSize / 2).Magnitude <= radius
	end

	local function getCamlockTarget(camera)
		local murderer = findPlayerWithRole("Murderer")
		local character = murderer and getAliveCharacter(murderer)
		local part = character and getAimPart(character)

		if not part then
			return nil
		end

		if Config.camlockFov and not inFov(camera, part.Position, Config.camlockFovRadius) then
			return nil
		end

		if Config.camlockWallCheck and not isVisible(camera, part, character) then
			return nil
		end

		return part
	end

	local function updateCamlock()
		if not Config.camlock or getHeldTool() ~= "Gun" then
			return
		end

		local camera = workspaceService.CurrentCamera

		if not camera then
			return
		end

		camlockParams.FilterDescendantsInstances = { localPlayer.Character }

		local part = getCamlockTarget(camera)

		if not part then
			return
		end

		local goal = CFrame.new(camera.CFrame.Position, predictPosition(part, Config.camlockPrediction))
		camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(Config.camlockSmoothing, 0.01, 1))
	end

	local busy = false

	local function grabGun()
		if busy then
			return
		end

		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if not root then
			notify("Your character is not loaded.")
			return
		end

		local drop = workspaceService:FindFirstChild("GunDrop", true)

		if not drop or not drop:IsA("BasePart") then
			notify("No gun on the ground.")
			return
		end

		busy = true

		local home = root.CFrame
		root.CFrame = drop.CFrame

		if typeof(firetouchinterest) == "function" then
			pcall(firetouchinterest, root, drop, 0)
			pcall(firetouchinterest, root, drop, 1)
		end

		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		local waited = 0

		while waited < 0.6 and not (backpack and backpack:FindFirstChild("Gun")) and not character:FindFirstChild("Gun") do
			waited += task.wait()
		end

		local gotGun = (backpack and backpack:FindFirstChild("Gun")) or character:FindFirstChild("Gun")

		if root.Parent then
			root.CFrame = home
		end

		busy = false
		notify(gotGun and "Grabbed the gun." or "Could not grab the gun.")
	end

	local ignoredPlayers = {}
	local selectedTarget = nil

	local function getPlayerNames()
		local names = {}

		for _, player in next, playersService:GetPlayers() do
			if player ~= localPlayer then
				table.insert(names, player.Name)
			end
		end

		table.sort(names)

		return names
	end

	local function getTool(name)
		local character = localPlayer.Character

		if not character then
			return nil
		end

		local tool = character:FindFirstChild(name)

		if tool and tool:IsA("Tool") then
			return tool
		end

		local backpack = localPlayer:FindFirstChildOfClass("Backpack")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		tool = backpack and backpack:FindFirstChild(name)

		if not tool or not humanoid then
			return nil
		end

		humanoid:EquipTool(tool)

		local waited = 0

		while tool.Parent ~= character and waited < 1 do
			waited += task.wait()
		end

		return tool.Parent == character and tool or nil
	end

	local function getKnife()
		return getTool("Knife")
	end

	autoEquipFor = function(role)
		if not Config.autoEquip then
			return
		end

		if role == "Murderer" then
			task.spawn(getTool, "Knife")
		elseif role == "Sheriff" then
			task.spawn(getTool, "Gun")
		end
	end

	onRolesUpdated = function()
		local role = getRole(localPlayer)

		if role ~= lastSelfRole then
			local previous = lastSelfRole
			lastSelfRole = role

			if previous and Config.roleAlerts then
				notify("You are now " .. (role == "Innocent" and "an Innocent" or ("the " .. role)) .. ".")
				playAlertSound()
			end

			autoEquipFor(role)
		end

		if not Config.roleAlerts or role == "Murderer" then
			return
		end

		local murderer = findPlayerWithRole("Murderer")
		local character = localPlayer.Character
		local murdererCharacter = murderer and getAliveCharacter(murderer)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local murdererRoot = murdererCharacter and murdererCharacter:FindFirstChild("HumanoidRootPart")

		if not root or not murdererRoot then
			return
		end

		local distance = (root.Position - murdererRoot.Position).Magnitude

		if distance <= Config.proximityDistance and os.clock() - lastProximityAlert > Config.proximityCooldown then
			lastProximityAlert = os.clock()
			notify(string.format("Murderer is close! (%d studs)", math.floor(distance)))
			playAlertSound()
		end
	end

	local function stab(knife, targetRoot)
		pcall(function()
			knife:Activate()
		end)

		local handle = knife:FindFirstChild("Handle")

		if handle and typeof(firetouchinterest) == "function" then
			pcall(firetouchinterest, handle, targetRoot, 0)
			pcall(firetouchinterest, handle, targetRoot, 1)
		end

		local events = knife:FindFirstChild("Events")
		local remote = events and events:FindFirstChild("HandleTouched")

		if remote and remote:IsA("RemoteEvent") then
			pcall(remote.FireServer, remote, targetRoot)
		end
	end

	local function killTargets(list, label)
		if busy then
			return
		end

		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if not root then
			notify("Your character is not loaded.")
			return
		end

		if #list == 0 then
			notify(label .. ": nobody to kill.")
			return
		end

		local knife = getKnife()

		if not knife then
			notify("You do not have the knife.")
			return
		end

		busy = true

		local home = root.CFrame
		local killed = 0

		for _, player in next, list do
			if not alive or not root.Parent then
				break
			end

			if not getAliveCharacter(player) then
				continue
			end

			local deadline = os.clock() + 3

			while alive and root.Parent and os.clock() < deadline do
				local targetCharacter = getAliveCharacter(player)
				local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

				if not targetRoot then
					break
				end

				root.CFrame = CFrame.lookAt((targetRoot.CFrame * CFrame.new(0, 0, 1.8)).Position, targetRoot.Position)
				root.AssemblyLinearVelocity = Vector3.zero
				stab(knife, targetRoot)
				task.wait(0.12)
			end

			if not getAliveCharacter(player) then
				killed += 1
			end
		end

		if Config.killReturn and root.Parent then
			root.CFrame = home
		end

		busy = false
		notify(string.format("%s: %d killed.", label, killed))
	end

	local function killAll()
		local list = {}

		for _, player in next, playersService:GetPlayers() do
			if player ~= localPlayer and not ignoredPlayers[player.Name] and getAliveCharacter(player) then
				table.insert(list, player)
			end
		end

		task.spawn(killTargets, list, "Kill all")
	end

	local function killSheriff()
		local list = {}

		for _, player in next, playersService:GetPlayers() do
			local role = player ~= localPlayer and getRole(player)

			if (role == "Sheriff" or role == "Hero") and getAliveCharacter(player) then
				table.insert(list, player)
			end
		end

		task.spawn(killTargets, list, "Kill sheriff")
	end

	local function killSelected()
		local player = selectedTarget and playersService:FindFirstChild(selectedTarget)

		if not player or not player:IsA("Player") then
			notify("Pick a player first.")
			return
		end

		task.spawn(killTargets, { player }, "Kill " .. player.Name)
	end

	local flingCancel = false

	local function flingTargets(list, label)
		if busy then
			return
		end

		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not root or not humanoid then
			notify("Your character is not loaded.")
			return
		end

		if #list == 0 then
			notify(label .. ": nobody to fling.")
			return
		end

		busy = true
		flingCancel = false

		local home = root.CFrame
		local savedProperties = root.CustomPhysicalProperties
		local changedParts = {}

		humanoid.PlatformStand = true
		root.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)

		for _, descendant in next, character:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= root and descendant.CanCollide then
				descendant.CanCollide = false
				changedParts[descendant] = true
			end
		end

		local angular = Instance.new("BodyAngularVelocity")
		angular.AngularVelocity = Vector3.new(0, 99999, 0)
		angular.MaxTorque = Vector3.new(0, math.huge, 0)
		angular.P = math.huge
		angular.Parent = root

		local flung = 0
		local flip = false
		local angle = 0
		local spin = 0

		for _, player in next, list do
			if not alive or flingCancel or not root.Parent then
				break
			end

			local startedAt = os.clock()

			while alive and not flingCancel and root.Parent and os.clock() - startedAt < FLING_TIMEOUT do
				local targetCharacter = player.Character
				local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
				local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")

				if not player.Parent or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
					break
				end

				if targetRoot.AssemblyLinearVelocity.Magnitude > FLING_SUCCESS_SPEED then
					flung += 1
					break
				end

				local center = targetRoot.Position + targetRoot.AssemblyLinearVelocity * 0.1
				local radius = Config.flingRadius * (0.5 + 0.5 * math.sin(angle * 0.45))
				local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle * 1.7) * 1.2, math.sin(angle) * radius)

				root.CFrame = CFrame.new(center + offset) * CFrame.Angles(0, spin, 0)
				flip = not flip
				root.AssemblyLinearVelocity = flip and Vector3.new(1e4, 1e4, 1e4) or Vector3.zero
				root.AssemblyAngularVelocity = Vector3.new(0, 1e5, 0)

				local deltaTime = runService.Heartbeat:Wait()
				angle += Config.flingSpeed * deltaTime
				spin += 90 * deltaTime
			end
		end

		angular:Destroy()

		for part in next, changedParts do
			if part.Parent then
				part.CanCollide = true
			end
		end

		humanoid.PlatformStand = false

		if root.Parent then
			root.CustomPhysicalProperties = savedProperties

			if Config.flingReturn then
				root.CFrame = home
			end

			for _ = 1, 15 do
				if not root.Parent then
					break
				end

				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				runService.Heartbeat:Wait()
			end
		end

		busy = false
		notify(string.format("%s: %d flung.", label, flung))
	end

	local function flingMurderer()
		local murderer = findPlayerWithRole("Murderer")

		task.spawn(flingTargets, murderer and { murderer } or {}, "Fling murderer")
	end

	local function flingSheriff()
		local list = {}

		for _, player in next, playersService:GetPlayers() do
			local role = player ~= localPlayer and getRole(player)

			if role == "Sheriff" or role == "Hero" then
				table.insert(list, player)
			end
		end

		task.spawn(flingTargets, list, "Fling sheriff")
	end

	local function flingSelected()
		local player = selectedTarget and playersService:FindFirstChild(selectedTarget)

		if not player or not player:IsA("Player") then
			notify("Pick a player first.")
			return
		end

		task.spawn(flingTargets, { player }, "Fling " .. player.Name)
	end

	local function flingAll()
		local list = {}

		for _, player in next, playersService:GetPlayers() do
			if player ~= localPlayer and not ignoredPlayers[player.Name] and getAliveCharacter(player) then
				table.insert(list, player)
			end
		end

		task.spawn(flingTargets, list, "Fling all")
	end

	local virtualInput = nil

	pcall(function()
		virtualInput = game:GetService("VirtualInputManager")
	end)

	local function triggerTool(tool, method)

		if method == "Activate" then
			pcall(function()
				tool:Activate()
			end)

			return
		end

		local camera = workspaceService.CurrentCamera

		if not virtualInput or not camera then
			return
		end

		local center = camera.ViewportSize / 2

		if method == "Mouse 1" or method == "Mouse 2" then
			local button = method == "Mouse 1" and 0 or 1

			pcall(function()
				virtualInput:SendMouseButtonEvent(center.X, center.Y, button, true, game, 0)
				task.wait()
				virtualInput:SendMouseButtonEvent(center.X, center.Y, button, false, game, 0)
			end)

			return
		end

		local keyCode = method == "Key Q" and Enum.KeyCode.Q or Enum.KeyCode.E

		pcall(function()
			virtualInput:SendKeyEvent(true, keyCode, false, game)
			task.wait()
			virtualInput:SendKeyEvent(false, keyCode, false, game)
		end)
	end

	local function teleportToMurderer(shoot)
		if busy then
			return
		end

		local murderer = findPlayerWithRole("Murderer")
		local murdererCharacter = murderer and getAliveCharacter(murderer)
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if not murdererCharacter or not murdererCharacter:FindFirstChild("HumanoidRootPart") then
			notify("No murderer found.")
			return
		end

		if not root then
			notify("Your character is not loaded.")
			return
		end

		local gun = nil

		if shoot then
			gun = getTool("Gun")

			if not gun then
				notify("You do not have the gun.")
				return
			end
		end

		busy = true

		local home = root.CFrame
		local deadline = os.clock() + (shoot and 4 or 0.4)

		while alive and root.Parent and os.clock() < deadline do
			local targetCharacter = getAliveCharacter(murderer)
			local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

			if not targetRoot then
				break
			end

			root.CFrame = CFrame.lookAt((targetRoot.CFrame * CFrame.new(0, 0, Config.tpDistance)).Position, targetRoot.Position)
			root.AssemblyLinearVelocity = Vector3.zero

			if shoot then
				local camera = workspaceService.CurrentCamera

				if camera then
					camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetRoot.Position)
				end

				task.spawn(triggerTool, gun, Config.shootInput)
			end

			task.wait(0.12)
		end

		local killed = not getAliveCharacter(murderer)

		if shoot and Config.tpReturn and root.Parent then
			root.CFrame = home
		end

		busy = false

		if shoot then
			notify(killed and "Murderer is dead." or "Murderer is still alive.")
		end
	end

	local silentTarget = nil
	local silentPosition = nil
	local silentMinDot = 0

	local function updateSilentTarget()
		silentTarget = nil
		silentPosition = nil

		if not Config.silentAim or busy or getHeldTool() ~= "Gun" then
			return
		end

		local camera = workspaceService.CurrentCamera
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not camera or not humanoid or humanoid.Health <= 0 then
			return
		end

		camlockParams.FilterDescendantsInstances = { character }

		local murderer = findPlayerWithRole("Murderer")
		local targetCharacter = murderer and getAliveCharacter(murderer)
		local part = targetCharacter and getAimPart(targetCharacter, Config.silentPart)

		if not part then
			return
		end

		if Config.silentUseFov and not inFov(camera, part.Position, Config.silentFovRadius) then
			return
		end

		if Config.silentWallCheck and not isVisible(camera, part, targetCharacter) then
			return
		end

		if Config.silentInnocentCheck then
			local origin = camera.CFrame.Position
			local result = workspaceService:Raycast(origin, part.Position - origin, camlockParams)
			local blocker = result and result.Instance:FindFirstAncestorOfClass("Model")

			if blocker and blocker ~= targetCharacter and blocker:FindFirstChildOfClass("Humanoid") then
				return
			end
		end

		silentTarget = part
		silentPosition = predictPosition(part, Config.silentPrediction)

		if Config.silentUseFov then
			local focal = (camera.ViewportSize.Y / 2) / math.tan(math.rad(camera.FieldOfView) / 2)
			local maxAngle = math.atan(Config.silentFovRadius / focal) * 1.5 + math.rad(4)
			silentMinDot = math.cos(math.min(maxAngle, math.rad(89)))
		else
			silentMinDot = 0
		end
	end

	pcall(runService.UnbindFromRenderStep, runService, SILENT_NAME)
	runService:BindToRenderStep(SILENT_NAME, Enum.RenderPriority.Camera.Value + 1, protect("Silent aim", updateSilentTarget))

	local hookState = shared.MM2Hooks

	if not hookState then
		hookState = {}
		shared.MM2Hooks = hookState
	end

	local mouse = localPlayer:GetMouse()
	local setNamecall = setnamecallmethod or function() end
	local HookManager = {}

	function HookManager.hookNamecall()
		if hookState.oldNamecall then
			return
		end

		hookState.oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			local handler = hookState.namecall

			if not handler then
				return hookState.oldNamecall(self, ...)
			end

			return handler(method, self, ...)
		end))
	end

	function HookManager.hookIndex()
		if hookState.oldIndex then
			return
		end

		hookState.oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
			local handler = hookState.index

			if not handler then
				return hookState.oldIndex(self, key)
			end

			return handler(self, key)
		end))
	end

	function HookManager.remove()
		hookState.namecall = nil
		hookState.index = nil

		if not hookState.oldNamecall and not hookState.oldIndex then
			return true
		end

		if typeof(restorefunction) ~= "function" or typeof(getrawmetatable) ~= "function" then
			return false
		end

		local metatable = getrawmetatable(game)
		local restored = true

		if hookState.oldNamecall then
			if pcall(restorefunction, metatable.__namecall) then
				hookState.oldNamecall = nil
			else
				restored = false
			end
		end

		if hookState.oldIndex then
			if pcall(restorefunction, metatable.__index) then
				hookState.oldIndex = nil
			else
				restored = false
			end
		end

		return restored
	end

	local function isCore()
		if typeof(getcallingscript) ~= "function" then
			return false
		end

		local success, caller = pcall(getcallingscript)

		while success and caller do
			if caller.Name == "PlayerModule" then
				return true
			end

			caller = caller.Parent
		end

		return false
	end

	local function canRedirect()
		if checkcaller() then
			return false
		end

		return not isCore()
	end

	local function redirect(origin, direction)
		local delta = silentPosition - origin
		local deltaLength = delta.Magnitude
		local directionLength = direction.Magnitude

		if deltaLength < 0.001 or directionLength < 0.001 then
			return nil
		end

		local dot = (delta.X * direction.X + delta.Y * direction.Y + delta.Z * direction.Z) / (deltaLength * directionLength)

		if dot < silentMinDot then
			return nil
		end

		return delta / deltaLength * directionLength
	end

	local lastRedirectNote = 0

	local function noteRedirect(path)
		if not Config.silentDebug then
			return
		end

		local now = os.clock()

		if now - lastRedirectNote < 1.5 then
			return
		end

		lastRedirectNote = now
		task.defer(notify, "Silent aim redirected via " .. path .. ".")
	end

	local function isGunRemote(remote)
		local current = remote.Parent

		for _ = 1, 5 do
			if not current then
				return false
			end

			if current.Name == "Gun" then
				return true
			end

			current = current.Parent
		end

		return false
	end

	local function onNamecall(method, self, ...)
		local oldNamecall = hookState.oldNamecall
		local camera = workspaceService.CurrentCamera

		if alive and silentPosition and (method == "FireServer" or method == "InvokeServer") and typeof(self) == "Instance" and canRedirect() and isGunRemote(self) then
			local args = table.pack(...)
			local lastVector = nil

			for index = 1, args.n do
				if typeof(args[index]) == "Vector3" then
					lastVector = index
				end
			end

			if lastVector then
				args[lastVector] = silentPosition
				noteRedirect("the gun remote")
				setNamecall(method)
				return oldNamecall(self, table.unpack(args, 1, args.n))
			end
		end

		if not alive or not silentPosition or (self ~= workspaceService and self ~= camera) then
			return oldNamecall(self, ...)
		end

		if self == workspaceService then
			if method == "Raycast" then
				local origin, direction = ...

				if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
					local redirected = redirect(origin, direction)

					if redirected and canRedirect() then
						noteRedirect("Raycast")
						setNamecall(method)
						return oldNamecall(self, origin, redirected, select(3, ...))
					end
				end
			elseif LEGACY_RAY_METHODS[method] then
				local ray = ...

				if typeof(ray) == "Ray" then
					local redirected = redirect(ray.Origin, ray.Direction)

					if redirected and canRedirect() then
						noteRedirect(method)
						setNamecall(method)
						return oldNamecall(self, Ray.new(ray.Origin, redirected), select(2, ...))
					end
				end
			end
		elseif SCREEN_RAY_METHODS[method] then
			local ray = oldNamecall(self, ...)

			if typeof(ray) ~= "Ray" then
				return ray
			end

			local redirected = redirect(ray.Origin, ray.Direction)

			if redirected and canRedirect() then
				noteRedirect(method)
				return Ray.new(ray.Origin, redirected)
			end

			return ray
		end

		setNamecall(method)
		return oldNamecall(self, ...)
	end

	local function onIndex(self, key)
		if self == mouse and MOUSE_KEYS[key] and alive and silentPosition and canRedirect() then
			noteRedirect("Mouse." .. key)

			if key == "Hit" then
				return CFrame.new(silentPosition)
			end

			if key == "Target" then
				return silentTarget
			end

			local origin = workspaceService.CurrentCamera.CFrame.Position
			return Ray.new(origin, (silentPosition - origin).Unit)
		end

		return hookState.oldIndex(self, key)
	end

	local function applyHooks()
		if typeof(hookmetamethod) ~= "function" or typeof(newcclosure) ~= "function" or typeof(getnamecallmethod) ~= "function" or typeof(checkcaller) ~= "function" then
			return false, "executor is missing hookmetamethod, newcclosure, getnamecallmethod or checkcaller"
		end

		local success, message = pcall(HookManager.hookNamecall)

		if not success then
			return false, tostring(message)
		end

		hookState.namecall = onNamecall

		local indexSuccess, indexMessage = pcall(HookManager.hookIndex)

		if indexSuccess then
			hookState.index = onIndex
		else
			notify("Mouse hook unavailable: " .. tostring(indexMessage))
		end

		return true
	end

	local fovVisuals = {}

	if drawingSupported then
		fovVisuals.camlock = maid:add(FovVisual.new())
		fovVisuals.silent = maid:add(FovVisual.new())
	end

	local function updateFovCircle()
		local camera = workspaceService.CurrentCamera

		if not camera then
			return
		end

		local center = camera.ViewportSize / 2

		if fovVisuals.camlock then
			fovVisuals.camlock:update(Config.camlock and Config.camlockFov and Config.camlockFovShow, center, Config.camlockFovRadius, Config.camlockFovColor, Config.camlockFovFilled, Config.fovOpacity, Config.fovRainbow)
		end

		if fovVisuals.silent then
			fovVisuals.silent:update(Config.silentAim and Config.silentUseFov and Config.silentFovShow, center, Config.silentFovRadius, Config.silentFovColor, Config.silentFovFilled, Config.fovOpacity, Config.fovRainbow)
		end

		if wallDebugLine and not Config.wallCheckDebug then
			wallDebugLine.Visible = false
		end

		if murdererArrowTriangle then
			local murderer = Config.murdererArrow and getRole(localPlayer) ~= "Murderer" and findPlayerWithRole("Murderer")
			local murdererCharacter = murderer and getAliveCharacter(murderer)
			local murdererRoot = murdererCharacter and murdererCharacter:FindFirstChild("HumanoidRootPart")

			if murdererRoot then
				updateArrow(murdererArrowTriangle, camera, murdererRoot.Position, Config.murdererColor)
			else
				murdererArrowTriangle.Visible = false
			end
		end
	end

	maid:add(runService.RenderStepped:Connect(protect("FOV circle", updateFovCircle)))

	local coinContainer = nil
	local visitedCoins = setmetatable({}, { __mode = "k" })

	local function getCoinContainer()
		if coinContainer and coinContainer.Parent then
			return coinContainer
		end

		coinContainer = nil

		for _, child in next, workspaceService:GetChildren() do
			local container = child:FindFirstChild("CoinContainer")

			if container then
				coinContainer = container
				return container
			end
		end

		return nil
	end

	local function hasTouch(coin)
		return coin:FindFirstChild("TouchInterest") ~= nil or coin:FindFirstChildWhichIsA("TouchTransmitter") ~= nil
	end

	local function containerHasTouch(container)
		for _, coin in next, container:GetChildren() do
			if coin:IsA("BasePart") and hasTouch(coin) then
				return true
			end
		end

		return false
	end

	local function getMurdererPosition()
		if not Config.farmAvoid or getRole(localPlayer) == "Murderer" then
			return nil
		end

		local murderer = findPlayerWithRole("Murderer")
		local character = murderer and getAliveCharacter(murderer)
		local root = character and character:FindFirstChild("HumanoidRootPart")

		return root and root.Position or nil
	end

	local function nearestCoin(container, origin, requireTouch)
		local best = nil
		local bestDistance = math.huge
		local now = os.clock()
		local avoidPosition = getMurdererPosition()

		for _, coin in next, container:GetChildren() do
			if not coin:IsA("BasePart") then
				continue
			end

			if requireTouch and not hasTouch(coin) then
				continue
			end

			local last = visitedCoins[coin]

			if last and now - last < COIN_RETRY_SECONDS then
				continue
			end

			if avoidPosition and (coin.Position - avoidPosition).Magnitude < Config.farmAvoidDistance then
				continue
			end

			local distance = (coin.Position - origin).Magnitude

			if distance < bestDistance then
				best = coin
				bestDistance = distance
			end
		end

		return best
	end

	local function collectCoin(root, coin)
		local usedTouch = hasTouch(coin)
		local distance = (coin.Position - root.Position).Magnitude
		local duration = math.max(distance / math.clamp(Config.farmSpeed, 1, FARM_MAX_SPEED), 0.05)
		local tween = tweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.new(coin.Position) })

		local aborted = false
		local nextCheck = 0

		tween:Play()

		while alive and Config.autoFarm and not busy and coin.Parent and root.Parent and (not usedTouch or hasTouch(coin)) and tween.PlaybackState == Enum.PlaybackState.Playing do
			if os.clock() >= nextCheck then
				nextCheck = os.clock() + 0.1

				local danger = getMurdererPosition()

				if danger and ((danger - root.Position).Magnitude < Config.farmAvoidDistance * 0.6 or (danger - coin.Position).Magnitude < Config.farmAvoidDistance) then
					aborted = true
					break
				end
			end

			task.wait()
		end

		tween:Cancel()
		visitedCoins[coin] = os.clock()

		if aborted then
			return
		end

		if not coin.Parent or not root.Parent then
			return
		end

		if usedTouch and not hasTouch(coin) then
			return
		end

		if typeof(firetouchinterest) == "function" then
			pcall(firetouchinterest, root, coin, 0)
			task.wait()
			pcall(firetouchinterest, root, coin, 1)
		end

		task.wait(0.25)
	end

	task.spawn(function()
		while alive do
			task.wait()

			if not Config.autoFarm or busy then
				continue
			end

			local character = localPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if not root or not humanoid or humanoid.Health <= 0 then
				task.wait(0.5)
				continue
			end

			local container = getCoinContainer()

			if not container then
				task.wait(0.5)
				continue
			end

			local coin = nearestCoin(container, root.Position, true)

			if not coin and not containerHasTouch(container) then
				coin = nearestCoin(container, root.Position, false)
			end

			if not coin then
				task.wait(0.3)
				continue
			end

			pcall(collectCoin, root, coin)
		end
	end)

	maid:add(runService.Stepped:Connect(function()
		local character = localPlayer.Character

		if (not Config.autoFarm and not Config.noclip) or not character then
			for part in next, noclipParts do
				if part.Parent then
					part.CanCollide = true
				end

				noclipParts[part] = nil
			end

			return
		end

		for _, part in next, character:GetChildren() do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
				noclipParts[part] = true
			end
		end

		local root = character:FindFirstChild("HumanoidRootPart")

		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end))

	local Esp = { all = {} }
	Esp.__index = Esp

	local espSettings = {
		outline = true,
		boxes = false,
		names = false,
		skeleton = false,
		tracers = false,
		health = false,
		color = Color3.new(1, 1, 1),
	}

	local function projectWorld(position)
		local point = workspaceService.CurrentCamera:WorldToViewportPoint(position)

		if point.Z <= 0 then
			return nil
		end

		return Vector2.new(point.X, point.Y)
	end

	function Esp.new(player)
		local self = setmetatable({}, Esp)
		self.player = player
		self.lines = {}
		self.label = nil
		self.character = nil
		self.humanoid = nil

		Esp.all[player] = self

		return self
	end

	function Esp:getLine(index)
		local line = self.lines[index]

		if not line then
			line = Drawing.new("Line")
			line.Transparency = 1
			line.Visible = false
			self.lines[index] = line
		end

		return line
	end

	function Esp:getLabel()
		if not self.label then
			local text = Drawing.new("Text")
			text.Center = true
			text.Outline = true
			text.Size = 13
			text.Visible = false
			self.label = text
		end

		return self.label
	end

	function Esp:hideLines(fromIndex)
		for index = fromIndex, #self.lines do
			self.lines[index].Visible = false
		end
	end

	function Esp:hideAll()
		self:hideLines(1)

		if self.label then
			self.label.Visible = false
		end
	end

	function Esp:update()
		local character = self.player.Character

		if character ~= self.character then
			self.character = character
			self.humanoid = nil
		end

		if character and not self.humanoid then
			self.humanoid = character:FindFirstChildOfClass("Humanoid")
		end

		local humanoid = self.humanoid
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspaceService.CurrentCamera

		if not Config.esp or not camera or not humanoid or not root or humanoid.Health <= 0 then
			self:hideAll()
			return
		end

		if (root.Position - camera.CFrame.Position).Magnitude > Config.espMaxDistance then
			self:hideAll()
			return
		end

		local role = getRole(self.player)

		if role == "Innocent" and not Config.showInnocents then
			self:hideAll()
			return
		end

		espSettings.color = roleColor(role)

		local tracerOrigin = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
		local healthFraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		local segments, bounds = computeShapes(character, projectWorld, espSettings, healthFraction, tracerOrigin)

		for index, segment in next, segments do
			local line = self:getLine(index)
			line.From = segment[1]
			line.To = segment[2]
			line.Color = segment[3]
			line.Thickness = segment[4]
			line.ZIndex = index
			line.Visible = true
		end

		self:hideLines(#segments + 1)

		if espSettings.names and bounds then
			local label = self:getLabel()
			label.Text = string.format("%s [%s]", self.player.Name, role)
			label.Color = espSettings.color
			label.Position = Vector2.new((bounds.left + bounds.right) / 2, bounds.top - 16)
			label.Visible = true
		elseif self.label then
			self.label.Visible = false
		end
	end

	function Esp:destroy()
		for _, line in next, self.lines do
			pcall(function()
				line:Remove()
			end)
		end

		self.lines = {}

		if self.label then
			pcall(function()
				self.label:Remove()
			end)

			self.label = nil
		end

		Esp.all[self.player] = nil
	end

	function Esp.updateAll()
		espSettings.outline = Config.espOutline
		espSettings.boxes = Config.espBoxes
		espSettings.names = Config.espNames
		espSettings.skeleton = Config.espSkeleton and not performanceActive
		espSettings.tracers = Config.espTracers and not performanceActive
		espSettings.health = Config.espHealth

		for _, esp in next, Esp.all do
			esp:update()
		end
	end

	local function addPlayer(player)
		if player ~= localPlayer and not Esp.all[player] then
			Esp.new(player)
		end
	end

	local function removePlayer(player)
		local esp = Esp.all[player]

		if esp then
			esp:destroy()
		end
	end

	local function cleanup()
		if not alive then
			return
		end

		alive = false
		showToast = nil
		setAntiAfk(false)
		stopFly()

		pcall(runService.UnbindFromRenderStep, runService, RENDER_NAME)
		pcall(runService.UnbindFromRenderStep, runService, CAMLOCK_NAME)
		pcall(runService.UnbindFromRenderStep, runService, SILENT_NAME)

		for part in next, noclipParts do
			if part.Parent then
				part.CanCollide = true
			end
		end

		maid:clean()

		for _, esp in next, table.clone(Esp.all) do
			esp:destroy()
		end

		for _, connection in next, connections do
			connection:Disconnect()
		end

		local hooksRestored = HookManager.remove()

		ui.destroy()

		shared.Magma = nil
		warn(hooksRestored and "[MM2] Unloaded, hooks restored." or "[MM2] Unloaded, hooks left inert.")
	end

	shared.Magma = { unload = cleanup }

	local antiAfkConnection = nil

	function setAntiAfk(enabled)
		if antiAfkConnection then
			antiAfkConnection:Disconnect()
			antiAfkConnection = nil
		end

		if not enabled then
			return
		end

		local virtualUser = game:GetService("VirtualUser")

		antiAfkConnection = localPlayer.Idled:Connect(function()
			pcall(function()
				virtualUser:CaptureController()
				virtualUser:ClickButton2(Vector2.new())
			end)
		end)
	end

	local watermark = make("TextLabel", {
		Name = "Watermark",
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.fromOffset(190, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Text = "magma",
		TextColor3 = THEME.textBright,
		TextSize = 11,
		Font = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Active = true,
		ZIndex = 6,
		Parent = ui.gui,
	})

	round(watermark, 8)
	addStroke(watermark, THEME.accentDark)

	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(26, 17, 22), Color3.fromRGB(11, 11, 14)),
		Rotation = 90,
		Parent = watermark,
	})

	local smoothedFps = 60
	local lastUtilityTick = 0

	local function updateUtility(deltaTime)
		if deltaTime and deltaTime > 0 then
			smoothedFps = smoothedFps * 0.9 + (1 / deltaTime) * 0.1
		end

		performanceActive = Config.performanceMode or (Config.performanceAuto and smoothedFps < Config.performanceThreshold)

		watermark.Visible = Config.showWatermark

		if not Config.showWatermark or os.clock() - lastUtilityTick < 0.3 then
			return
		end

		lastUtilityTick = os.clock()

		local pingText = "-- ms"

		local pingSuccess, pingValue = pcall(function()
			return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
		end)

		if pingSuccess and typeof(pingValue) == "number" then
			pingText = string.format("%d ms", math.floor(pingValue + 0.5))
		end

		watermark.Text = string.format("magma | %d fps | %s", math.floor(smoothedFps + 0.5), pingText)

		for _, entry in next, ui.keybindRegistry do
			if entry.display then
				entry.display:SetText(entry.label .. ":  " .. entry.bind.Describe(entry.bind.Key))
			end
		end
	end

	maid:add(runService.RenderStepped:Connect(protect("Utility", updateUtility)))

	local flyBodyVelocity = nil

	function stopFly()
		if flyBodyVelocity then
			flyBodyVelocity:Destroy()
			flyBodyVelocity = nil
		end

		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid.PlatformStand = false
		end
	end

	local function updateMovement()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if not character or not humanoid or not root then
			stopFly()
			return
		end

		if Config.walkSpeedEnabled then
			humanoid.WalkSpeed = Config.walkSpeedValue
		end

		if not Config.fly then
			if flyBodyVelocity then
				stopFly()
			end

			return
		end

		if not flyBodyVelocity or flyBodyVelocity.Parent ~= root then
			flyBodyVelocity = Instance.new("BodyVelocity")
			flyBodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
			flyBodyVelocity.Velocity = Vector3.zero
			flyBodyVelocity.Parent = root
		end

		local horizontal = humanoid.MoveDirection * Config.flySpeed
		local ascending = humanoid.Jump or userInputService:IsKeyDown(Enum.KeyCode.Space)

		if ascending then
			flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			flyBodyVelocity.Velocity = Vector3.new(horizontal.X, Config.flySpeed, horizontal.Z)
		else
			flyBodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
			flyBodyVelocity.Velocity = Vector3.new(horizontal.X, 0, horizontal.Z)
		end
	end

	maid:add(runService.Heartbeat:Connect(protect("Movement", updateMovement)))

	maid:add(userInputService.JumpRequest:Connect(function()
		if not Config.infiniteJump then
			return
		end

		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end))

	local function makeTapButton(button, onTap, canDrag)
		local pressing = false
		local moved = false
		local dragStart = nil
		local startPosition = nil

		maid:add(button.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			pressing = true
			moved = false
			dragStart = input.Position
			startPosition = button.Position

			local connection = nil

			connection = input.Changed:Connect(function()
				if input.UserInputState ~= Enum.UserInputState.End then
					return
				end

				connection:Disconnect()

				if pressing and not moved then
					pcall(onTap)
				end

				pressing = false
			end)
		end))

		maid:add(userInputService.InputChanged:Connect(function(input)
			if not pressing then
				return
			end

			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local delta = input.Position - dragStart

			if delta.Magnitude > 8 and (not canDrag or canDrag()) then
				moved = true
			end

			if moved then
				button.Position = UDim2.new(
					startPosition.X.Scale,
					startPosition.X.Offset + delta.X,
					startPosition.Y.Scale,
					startPosition.Y.Offset + delta.Y
				)
			end
		end))
	end

	local grabButton = make("TextButton", {
		Name = "GrabButton",
		Position = UDim2.new(1, -86, 0.5, -26),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Text = "",
		TextSize = 26,
		Font = FONT_BOLD,
		TextColor3 = THEME.textBright,
		AutoButtonColor = false,
		Active = true,
		Visible = Config.grabButton,
		Parent = gui,
	})

	round(grabButton, 14)
	addStroke(grabButton, THEME.accent).Thickness = 1.5

	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(80, 28, 38), Color3.fromRGB(24, 14, 18)),
		Rotation = 90,
		Parent = grabButton,
	})

	textLabel({
		Size = UDim2.fromScale(1, 1),
		Text = "GRAB",
		TextColor3 = THEME.textBright,
		Font = FONT_BOLD,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = grabButton,
	})

	local menuHome = menuButton.Position
	local grabHome = grabButton.Position

	makeTapButton(grabButton, function()
		task.spawn(grabGun)
	end, function()
		return not ui.getMenuLocked()
	end)

	local function addToggle(section, key, text, onChange)
		return section:AddToggle(text, Config[key], function(value)
			Config[key] = value

			if onChange then
				onChange(value)
			end
		end)
	end

	local function addSlider(section, key, text, minimum, maximum, rounding, suffix)
		return section:AddSlider(text, minimum, maximum, Config[key], rounding, function(value)
			Config[key] = value
		end, { suffix = suffix })
	end

	local function addDropdown(section, key, text, values)
		return section:AddDropdown(text, values, Config[key], function(value)
			if value then
				Config[key] = value
			end
		end)
	end

	local function addColor(section, key, text)
		return section:AddColor(text, Config[key], function(color)
			Config[key] = color
		end)
	end

	local function formatNumber(value)
		return tostring(math.floor(value * 1000 + 0.5) / 1000)
	end

	local function addPredictionControl(section, key, text)
		local slider = nil
		local input = nil

		slider = addSlider(section, key, text, 0, 1, 2)

		slider.Callback = function(value)
			Config[key] = value
			input:Set(formatNumber(value), true)
		end

		input = section:AddInput(text .. " (type)", formatNumber(Config[key]), function(typed)
			local number = tonumber(typed)

			if number then
				number = math.clamp(number, 0, 10)
				Config[key] = number
				slider:Set(math.clamp(number, 0, 1), true)
			end

			input:Set(formatNumber(Config[key]), true)
		end, "0 to 10")
	end

	-- Skin changer (client-side). Data is loaded at runtime from the repo, nothing is embedded here.
	local SKIN_REPO = "jealousyplsforgiveme-create/Not-a-rbx-script.gg"
	local SKIN_BRANCH = "main"
	local SKIN_URL = "" -- leave empty to auto-find the skin file in SKIN_REPO, or put a raw link here
	local SKIN_LOCAL_FILE = "Magma/skins.lua"
	local GRIP_OFFSET = CFrame.new()
	local MAX_REL_DISTANCE = 50
	local SKIN_SKIP = {
		Script = true, LocalScript = true, Sound = true, RigidConstraint = true, Weld = true,
		ManualWeld = true, WeldConstraint = true, EqualizerSoundEffect = true,
		SurfaceAppearance = true, Attachment = true, FileMesh = true, Beam = true,
	}

	local SkinData = {}
	local skinState = {}
	local skinSource = SKIN_URL

	local function httpGet(url)
		local requestFunction = request or http_request or (syn and syn.request)

		if not requestFunction then
			return nil, "executor has no request function"
		end

		local success, response = pcall(requestFunction, { Url = url, Method = "GET" })

		if not success or type(response) ~= "table" then
			return nil, "request failed"
		end

		if response.StatusCode ~= 200 then
			return nil, "HTTP " .. tostring(response.StatusCode)
		end

		return response.Body
	end

	-- Only runs files that look like the skin table, so other scripts in the repo are never executed.
	local function parseSkinBody(body)
		if type(body) ~= "string" or not string.find(body, "Model = {", 1, true) or not string.find(body, "Meta = {", 1, true) then
			return nil, "file is not a skin table"
		end

		local chunk, compileError = loadstring(body)

		if not chunk then
			return nil, tostring(compileError)
		end

		local ran, data = pcall(chunk)

		if not ran or type(data) ~= "table" then
			return nil, tostring(data)
		end

		for _, entry in next, data do
			if type(entry) == "table" and entry.Model and entry.Meta then
				return data
			end
		end

		return nil, "file is not a skin table"
	end

	local function discoverSkinData()
		local candidates = {}

		local function scan(path, depth)
			local body = httpGet(string.format("https://api.github.com/repos/%s/contents/%s?ref=%s", SKIN_REPO, path, SKIN_BRANCH))

			if not body then
				return
			end

			local decoded, list = pcall(function()
				return httpService:JSONDecode(body)
			end)

			if not decoded or type(list) ~= "table" then
				return
			end

			for _, item in next, list do
				if item.type == "file" and (string.match(item.name, "%.lua$") or string.match(item.name, "%.txt$")) and item.download_url then
					table.insert(candidates, item)
				elseif item.type == "dir" and depth < 2 then
					scan(item.path, depth + 1)
				end
			end
		end

		scan("", 0)

		-- The skin table is by far the biggest file, so try those first.
		table.sort(candidates, function(a, b)
			return (a.size or 0) > (b.size or 0)
		end)

		for index = 1, math.min(#candidates, 6) do
			local body = httpGet(candidates[index].download_url)
			local data = body and parseSkinBody(body)

			if data then
				return data, candidates[index].name
			end
		end

		return nil, "no skin file found in " .. SKIN_REPO
	end

	local function loadSkinData(source)
		if source == "" or string.find(source, "FILE_NAME", 1, true) then
			local data, info = discoverSkinData()

			if data then
				return data
			end

			if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(SKIN_LOCAL_FILE) then
				return parseSkinBody(readfile(SKIN_LOCAL_FILE))
			end

			return nil, info
		end

		local body, reason = httpGet(source)

		if not body then
			return nil, reason
		end

		return parseSkinBody(body)
	end

	local function buildSkinNode(node, rootPart, parent, baseCFrame)
		if SKIN_SKIP[node.Class] then
			return nil
		end

		local props = node.Props or {}
		local relative = props.RelCF or CFrame.identity

		if rootPart and relative.Position.Magnitude > MAX_REL_DISTANCE then
			return nil
		end

		local created, instance = pcall(Instance.new, node.Class)

		if not created then
			return nil
		end

		-- MeshId first so a later Size write isn't overridden by the mesh loading.
		if props.MeshId then
			pcall(function()
				instance.MeshId = props.MeshId
			end)
		end

		for key, value in next, props do
			if key ~= "RelCF" and key ~= "MeshId" then
				pcall(function()
					instance[key] = value
				end)
			end
		end

		local isPart = instance:IsA("BasePart")

		if isPart then
			instance.Anchored = false
			instance.CanCollide = false
			instance.CanQuery = false
			instance.CanTouch = false
			instance.Massless = true
			instance.CFrame = rootPart and rootPart.CFrame * relative or baseCFrame
		end

		instance.Parent = parent

		if isPart and rootPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rootPart
			weld.Part1 = instance
			weld.Parent = instance
		end

		local root = rootPart or (isPart and instance or nil)

		for _, child in next, node.Children or {} do
			buildSkinNode(child, root, instance, baseCFrame)
		end

		return instance
	end

	local function removeSkin(tool)
		local state = skinState[tool]

		if not state then
			return
		end

		skinState[tool] = nil

		for part, value in next, state.hidden do
			if part.Parent then
				part.LocalTransparencyModifier = value
			end
		end

		if state.container then
			state.container:Destroy()
		end
	end

	local function applySkin(tool, handle, key)
		local state = { key = key, hidden = {} }
		skinState[tool] = state

		for _, descendant in next, tool:GetDescendants() do
			if descendant:IsA("BasePart") then
				state.hidden[descendant] = descendant.LocalTransparencyModifier
				descendant.LocalTransparencyModifier = 1
			end
		end

		local container = Instance.new("Model")
		container.Name = "MagmaSkin"
		container.Parent = tool
		state.container = container

		local root = buildSkinNode(SkinData[key].Model, nil, container, handle.CFrame * GRIP_OFFSET)

		if not root or not root:IsA("BasePart") then
			notify("Skin " .. key .. " has no root part.")
			return
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = root
		weld.Parent = root
	end

	local function wantedSkin(tool)
		local key = (tool.Name == "Knife" and Config.knifeSkin) or (tool.Name == "Gun" and Config.gunSkin)

		if not key or key == "None" or not SkinData[key] then
			return nil
		end

		return key
	end

	local function updateSkins()
		local character = localPlayer.Character

		for tool, state in next, skinState do
			if not Config.skinChanger or tool.Parent ~= character or wantedSkin(tool) ~= state.key then
				removeSkin(tool)
			end
		end

		if not Config.skinChanger or not character then
			return
		end

		for _, tool in next, character:GetChildren() do
			if tool:IsA("Tool") and not skinState[tool] then
				local key = wantedSkin(tool)
				local handle = key and (tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart"))

				if key and handle then
					local success, message = pcall(applySkin, tool, handle, key)

					if not success then
						removeSkin(tool)
						notify("Skin apply failed: " .. tostring(message))
					end
				end
			end
		end
	end

	maid:add(runService.Heartbeat:Connect(protect("Skins", updateSkins)))

	maid:add(function()
		for tool in next, table.clone(skinState) do
			removeSkin(tool)
		end
	end)

	local mainTab = addTab("Main")
	local farmTab = addTab("Farm")
	local murdererTab = addTab("Murderer")
	local visualsTab = addTab("Visuals")
	local menuTab = addTab("Menu")

	safe("Main tab", function()
		local camlockSection = mainTab:AddSection("Camlock", 1)
		addToggle(camlockSection, "camlock", "Camlock")
		addSlider(camlockSection, "camlockSmoothing", "Sensitivity", 0.01, 1, 2)
		addDropdown(camlockSection, "camlockPart", "Hit Part", { "Head", "Torso", "Nearest" })
		addToggle(camlockSection, "camlockWallCheck", "Wall Check")
		addToggle(camlockSection, "camlockFov", "Use FOV")
		addToggle(camlockSection, "camlockPrediction", "Prediction")
		addPredictionControl(camlockSection, "predX", "Prediction X")
		addPredictionControl(camlockSection, "predY", "Prediction Y")
		addPredictionControl(camlockSection, "predZ", "Prediction Z")
		camlockSection:AddLabel("Only locks while you hold the Gun, and only on the murderer. Nearest hits the visible part closest to your crosshair, and picks between head and torso when they are fully in the open. FOV circle settings are in Visuals.", { wrap = true })

		local silentSection = mainTab:AddSection("Silent Aim", 2)
		local silentToggle = nil

		silentToggle = addToggle(silentSection, "silentAim", "Silent Aim", function(value)
			if not value then
				return
			end

			local success, reason = applyHooks()

			if success then
				return
			end

			Config.silentAim = false
			notify("Silent aim unavailable: " .. tostring(reason))
			silentToggle:Set(false, true)
		end)

		addDropdown(silentSection, "silentPart", "Hit Part", { "Head", "Torso", "Nearest" })
		addToggle(silentSection, "silentUseFov", "Use FOV")
		addToggle(silentSection, "silentWallCheck", "Wall Check")
		addToggle(silentSection, "silentInnocentCheck", "Innocent Check")
		addToggle(silentSection, "silentPrediction", "Prediction")
		addToggle(silentSection, "silentDebug", "Show Redirects")
		silentSection:AddLabel("Redirects your Gun shots to the murderer. Covers raycasts, the mouse and the gun's own remote. Innocent Check stops the redirect when another player is in the line of fire. Prediction uses the X, Y and Z values from Camlock. Show Redirects tells you which path the game used.", { wrap = true })

		local gunSection = mainTab:AddSection("Gun", 2)

		addToggle(gunSection, "grabButton", "Screen Button", function(value)
			grabButton.Visible = value
		end)

		gunSection:AddButton("Grab Gun", function()
			task.spawn(grabGun)
		end)

		local roleSection = mainTab:AddSection("Role", 2)
		addToggle(roleSection, "roleAlerts", "Role Alerts")
		addToggle(roleSection, "autoEquip", "Auto Equip Weapon")
		addSlider(roleSection, "proximityDistance", "Proximity Alert", 10, 200, 0, " st")
		roleSection:AddLabel("Notifies you when your role changes or the murderer gets close, and can equip your Gun or Knife automatically. The murderer arrow is in Visuals.", { wrap = true })
	end)

	safe("Farm tab", function()
		local farmSection = farmTab:AddSection("Auto Farm", 1)
		addToggle(farmSection, "autoFarm", "Auto Farm Coins")
		addSlider(farmSection, "farmSpeed", "Speed", 10, FARM_MAX_SPEED, 0, " st/s")
		addToggle(farmSection, "farmAvoid", "Avoid Murderer")
		addSlider(farmSection, "farmAvoidDistance", "Avoid Distance", 10, 100, 0, " st")

		local movementSection = farmTab:AddSection("Movement", 1)
		addToggle(movementSection, "noclip", "Noclip")
		addToggle(movementSection, "fly", "Fly")
		addSlider(movementSection, "flySpeed", "Fly Speed", 20, 200, 0, " st/s")
		addToggle(movementSection, "infiniteJump", "Infinite Jump")
		addToggle(movementSection, "walkSpeedEnabled", "Custom WalkSpeed")
		addSlider(movementSection, "walkSpeedValue", "WalkSpeed", 16, 100, 0)
		movementSection:AddLabel("Fly moves using your normal movement input and your jump button to go up.", { wrap = true })

		local sheriffSection = farmTab:AddSection("Sheriff", 2)

		sheriffSection:AddButton("Teleport To Murderer", function()
			task.spawn(teleportToMurderer, false)
		end)

		sheriffSection:AddButton("Teleport + Shoot", function()
			task.spawn(teleportToMurderer, true)
		end)

		addDropdown(sheriffSection, "shootInput", "Shoot Input", { "Activate", "Mouse 1" })
		addSlider(sheriffSection, "tpDistance", "Distance", 2, 15, 0, " st")
		addToggle(sheriffSection, "tpReturn", "Return After")
		sheriffSection:AddLabel("Teleports behind the murderer, aims the camera at them and shoots with your Gun.", { wrap = true })
	end)

	safe("Murderer tab", function()
		local killSection = murdererTab:AddSection("Kill", 1)

		killSection:AddButton("Kill All", function()
			killAll()
		end)

		killSection:AddButton("Kill Sheriff", function()
			killSheriff()
		end)

		local targetDropdown = killSection:AddDropdown("Player", getPlayerNames(), nil, function(value)
			selectedTarget = value
		end)

		killSection:AddButton("Kill Player", function()
			killSelected()
		end)

		addToggle(killSection, "killReturn", "Return After Kill")

		local ignoreSection = murdererTab:AddSection("Ignore", 2)

		local ignoreDropdown = ignoreSection:AddDropdown("Ignore Players", getPlayerNames(), {}, function(value)
			table.clear(ignoredPlayers)

			if type(value) ~= "table" then
				return
			end

			for name, enabled in next, value do
				if enabled then
					ignoredPlayers[name] = true
				end
			end
		end, { multi = true })

		ignoreSection:AddLabel("Ignored players are skipped by Kill All and Fling All.", { wrap = true })

		local flingSection = murdererTab:AddSection("Fling", 2)

		flingSection:AddButton("Fling Murderer", function()
			flingMurderer()
		end)

		flingSection:AddButton("Fling Sheriff", function()
			flingSheriff()
		end)

		flingSection:AddButton("Fling Player", function()
			flingSelected()
		end)

		flingSection:AddButton("Fling All", function()
			flingAll()
		end)

		flingSection:AddButton("Stop Fling", function()
			flingCancel = true
		end)

		addSlider(flingSection, "flingRadius", "Orbit Radius", 1, 8, 1, " st")
		addSlider(flingSection, "flingSpeed", "Orbit Speed", 4, 40, 0)
		addToggle(flingSection, "flingReturn", "Return After Fling")
		flingSection:AddLabel("Orbits around the target while spinning so it keeps up when they move. Fling Player uses the player picked in the Kill section.", { wrap = true })

		local function refreshPlayerLists()
			local names = getPlayerNames()

			targetDropdown:SetValues(names)
			ignoreDropdown:SetValues(names)
		end

		maid:add(playersService.PlayerAdded:Connect(function()
			task.delay(0.3, refreshPlayerLists)
		end))

		maid:add(playersService.PlayerRemoving:Connect(function()
			task.delay(0.3, refreshPlayerLists)
		end))
	end)

	safe("Visuals tab", function()
		local espSection = visualsTab:AddSection("Role ESP", 1)
		addToggle(espSection, "esp", "Enable ESP")
		addToggle(espSection, "espBoxes", "Boxes")
		addToggle(espSection, "espOutline", "Box Outline")
		addToggle(espSection, "espNames", "Names + Role")
		addToggle(espSection, "espSkeleton", "Skeleton")
		addToggle(espSection, "espTracers", "Tracers")
		addToggle(espSection, "espHealth", "Health Bar")
		addToggle(espSection, "showInnocents", "Show Innocents")
		addSlider(espSection, "espMaxDistance", "Range", 50, 10000, 0, " st")

		local colorSection = visualsTab:AddSection("Role Colors", 1)
		addColor(colorSection, "murdererColor", "Murderer")
		addColor(colorSection, "sheriffColor", "Sheriff")
		addColor(colorSection, "heroColor", "Hero")
		addColor(colorSection, "innocentColor", "Innocent")

		local skinSection = visualsTab:AddSection("Skins", 1)
		addToggle(skinSection, "skinChanger", "Skin Changer")

		local knifeDropdown = skinSection:AddDropdown("Knife Skin", { "None" }, "None", function(value)
			Config.knifeSkin = value or "None"
		end)

		local gunDropdown = skinSection:AddDropdown("Gun Skin", { "None" }, "None", function(value)
			Config.gunSkin = value or "None"
		end)

		local function reloadSkins()
			local data, reason = loadSkinData(skinSource)

			if not alive then
				return
			end

			if not data then
				notify("Skins unavailable: " .. tostring(reason))
				return
			end

			SkinData = data

			local knives, guns = {}, {}

			for key, entry in next, data do
				if type(entry) == "table" and entry.Complete and entry.Model and entry.Meta then
					if entry.Meta.ItemType == "Knife" then
						table.insert(knives, key)
					elseif entry.Meta.ItemType == "Gun" then
						table.insert(guns, key)
					end
				end
			end

			table.sort(knives)
			table.sort(guns)
			table.insert(knives, 1, "None")
			table.insert(guns, 1, "None")
			knifeDropdown:SetValues(knives)
			gunDropdown:SetValues(guns)
			notify(string.format("Loaded %d knife and %d gun skins.", #knives - 1, #guns - 1))
		end

		skinSection:AddInput("Skin Data URL (optional)", skinSource, function(value)
			skinSource = value
		end, "empty = auto-find in repo")

		skinSection:AddButton("Load Skins", function()
			task.spawn(reloadSkins)
		end)

		skinSection:AddLabel("Client-side only, applies while the Knife or Gun is held. Skins load from your repo automatically. Paste a raw link above only if you want a different file, then press Load Skins.", { wrap = true })

		task.spawn(reloadSkins)

		local camlockFovSection = visualsTab:AddSection("Camlock FOV", 2)
		addSlider(camlockFovSection, "camlockFovRadius", "FOV Radius", 20, 600, 0, " px")
		addToggle(camlockFovSection, "camlockFovShow", "Show FOV Circle")
		addToggle(camlockFovSection, "camlockFovFilled", "Filled FOV")
		addColor(camlockFovSection, "camlockFovColor", "FOV Color")

		local silentFovSection = visualsTab:AddSection("Silent FOV", 2)
		addSlider(silentFovSection, "silentFovRadius", "FOV Radius", 20, 600, 0, " px")
		addToggle(silentFovSection, "silentFovShow", "Show FOV Circle")
		addToggle(silentFovSection, "silentFovFilled", "Filled FOV")
		addColor(silentFovSection, "silentFovColor", "FOV Color")

		local styleSection = visualsTab:AddSection("FOV Style", 2)
		addSlider(styleSection, "fovOpacity", "Filled Opacity", 0.05, 1, 2)
		addToggle(styleSection, "fovRainbow", "Rainbow FOV")
		addToggle(styleSection, "wallCheckDebug", "Debug Wall Check")
		addToggle(styleSection, "murdererArrow", "Murderer Arrow")
		styleSection:AddLabel("Wall check debug draws a line from your crosshair to the target: green when clear, red when blocked. The arrow points at the murderer when they are off-screen.", { wrap = true })
	end)

	safe("Menu tab", function()
		local menuSection = menuTab:AddSection("Menu", 1)

		menuSection:AddKeybind("Menu Keybind", Enum.KeyCode.RightShift, function(key)
			ui.setMenuKey(key)
		end)

		menuSection:AddToggle("Lock Buttons", false, function(value)
			ui.setMenuLocked(value)
			Config.lockMenuButton = value
		end)

		menuSection:AddButton("Reset Button Positions", function()
			menuButton.Position = menuHome
			grabButton.Position = grabHome
		end)

		menuSection:AddButton("Hide Menu", function()
			setMenuVisible(false)
		end)

		local actionSection = menuTab:AddSection("Actions", 2)

		actionSection:AddButton("Unload", function()
			cleanup()
		end)

		local utilitySection = menuTab:AddSection("Utility", 2)
		addToggle(utilitySection, "showWatermark", "Show Watermark")

		addToggle(utilitySection, "antiAfk", "Anti-AFK", function(value)
			setAntiAfk(value)
		end)

		addToggle(utilitySection, "performanceMode", "Performance Mode")
		addToggle(utilitySection, "performanceAuto", "Auto Performance Mode")
		addSlider(utilitySection, "performanceThreshold", "Auto Threshold", 10, 60, 0, " fps")
		utilitySection:AddLabel("Performance Mode hides skeleton and tracer ESP lines to save frames. Auto turns it on by itself when your FPS drops below the threshold. Anti-AFK stops the game from kicking you for being idle.", { wrap = true })

		local overviewSection = menuTab:AddSection("Keybind Overview", 2)

		if #ui.keybindRegistry == 0 then
			overviewSection:AddLabel("No keybinds registered yet.", { wrap = true })
		else
			for _, entry in next, ui.keybindRegistry do
				entry.display = overviewSection:AddLabel(entry.label .. ":  " .. entry.bind.Describe(entry.bind.Key))
			end
		end
	end)

	selectTab(tabs[1])
	setMenuVisible(true)

	safe("ESP", function()
		if not drawingSupported then
			notify("Your executor has no Drawing library, so ESP is unavailable.")
			return
		end

		for _, player in next, playersService:GetPlayers() do
			addPlayer(player)
		end

		maid:add(playersService.PlayerAdded:Connect(addPlayer))
		maid:add(playersService.PlayerRemoving:Connect(removePlayer))

		pcall(runService.UnbindFromRenderStep, runService, RENDER_NAME)
		runService:BindToRenderStep(RENDER_NAME, RENDER_PRIORITY, protect("ESP", Esp.updateAll))
	end)

	safe("Camlock", function()
		pcall(runService.UnbindFromRenderStep, runService, CAMLOCK_NAME)
		runService:BindToRenderStep(CAMLOCK_NAME, Enum.RenderPriority.Camera.Value + 2, protect("Camlock", updateCamlock))
	end)

	notify("Loaded. RightShift or the M button opens the menu.")
end

local function runUniversal()
	local ui = createUi("universal", "universal")
	local addTab = ui.addTab
	local selectTab = ui.selectTab
	local connections = ui.connections

	local localPlayer = playersService.LocalPlayer
	local mouse = localPlayer:GetMouse()
	local setNamecall = setnamecallmethod or function() end
	local alive = true
	local busy = false
	local performanceActive = false

	-- Declared up front so cleanup() can reach them regardless of definition order.
	local setAntiAfk, stopFly
	local noclipParts = {}

	local Config = {
		camlock = false,
		camlockMode = "Always",
		camlockKey = Enum.UserInputType.MouseButton2,
		camlockSmoothing = 0.25,
		camlockPart = "Head",
		camlockUseFov = true,
		camlockFovRadius = 150,
		camlockFovShow = false,
		camlockFovFilled = false,
		camlockFovColor = Color3.fromRGB(255, 255, 255),
		silentAim = false,
		silentPart = "Head",
		silentUseFov = true,
		silentFovRadius = 200,
		silentFovShow = false,
		silentFovFilled = false,
		silentFovColor = Color3.fromRGB(255, 60, 60),
		fovOpacity = 0.15,
		fovRainbow = false,
		movableFov = false,
		fovPosition = nil,
		targetPlayers = true,
		targetNpcs = false,
		priority = "Center",
		maxDistance = 2000,
		teamCheck = false,
		wallCheck = false,
		forceFieldCheck = false,
		ignoreBots = false,
		sticky = false,
		predictionEnabled = false,
		predX = 0.13,
		predY = 0.13,
		predZ = 0.13,
		triggerbot = false,
		triggerDelay = 0.05,
		hitboxExpander = false,
		hitboxSize = 3,
		esp = false,
		espNpcs = false,
		espBoxes = true,
		espOutline = true,
		espNames = false,
		espDistance = false,
		espSkeleton = false,
		espTracers = false,
		espHealth = false,
		espMaxDistance = 1500,
		hideTeammates = false,
		boxColor = Color3.fromRGB(255, 255, 255),
		skeletonColor = Color3.fromRGB(255, 255, 255),
		autoTeamColors = false,
		enemyTeamColor1 = Color3.fromRGB(255, 60, 60),
		enemyTeamColor2 = Color3.fromRGB(70, 220, 90),
		teammateUseGameColor = false,
		teammateColor = Color3.fromRGB(80, 160, 255),
		flingRadius = 2,
		flingSpeed = 18,
		flingReturn = true,
		wallCheckDebug = false,
		showWatermark = false,
		antiAfk = false,
		performanceMode = false,
		performanceAuto = true,
		performanceThreshold = 30,
		noclip = false,
		fly = false,
		flySpeed = 60,
		infiniteJump = false,
		walkSpeedEnabled = false,
		walkSpeedValue = 32,
		targetArrow = false,
	}

	local function isNpc(entity)
		return type(entity) == "table"
	end

	local PlayerLists = { ignored = {}, targeted = {} }
	local TeamTargets = {}
	local selectedPlayer = nil

	local Maid = {}
	Maid.__index = Maid

	function Maid.new()
		return setmetatable({ tasks = {} }, Maid)
	end

	function Maid:add(item)
		table.insert(self.tasks, item)
		return item
	end

	function Maid:clean()
		local tasks = self.tasks
		self.tasks = {}

		for index = #tasks, 1, -1 do
			local item = tasks[index]
			local itemType = typeof(item)

			if itemType == "function" then
				pcall(item)
			elseif itemType == "RBXScriptConnection" then
				item:Disconnect()
			elseif itemType == "Instance" then
				item:Destroy()
			else
				local success, remover = pcall(function()
					return item.destroy or item.Remove or item.Destroy
				end)

				if success and remover then
					pcall(remover, item)
				end
			end
		end
	end

	local maid = Maid.new()

	local function safe(label, callback, ...)
		local success, message = pcall(callback, ...)

		if not success then
			notify(string.format("%s failed: %s", label, tostring(message)))
		end

		return success
	end

	local function protect(label, callback)
		local lastMessage = nil

		return function(...)
			local success, message = pcall(callback, ...)

			if success or message == lastMessage then
				return
			end

			lastMessage = message
			notify(string.format("%s error: %s", label, tostring(message)))
		end
	end

	local drawingSupported = pcall(function()
		Drawing.new("Line"):Remove()
	end)

	local hookState = shared.MagmaHooks

	if not hookState then
		hookState = {}
		shared.MagmaHooks = hookState
	end

	local HookManager = {}

	function HookManager.hookNamecall()
		if hookState.oldNamecall then
			return
		end

		hookState.oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local method = getnamecallmethod()
			local handler = hookState.namecall

			if not handler then
				return hookState.oldNamecall(self, ...)
			end

			return handler(method, self, ...)
		end))
	end

	function HookManager.hookIndex()
		if hookState.oldIndex then
			return
		end

		hookState.oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
			local handler = hookState.index

			if not handler then
				return hookState.oldIndex(self, key)
			end

			return handler(self, key)
		end))
	end

	function HookManager.remove()
		hookState.namecall = nil
		hookState.index = nil

		if not hookState.oldNamecall and not hookState.oldIndex then
			return true
		end

		if typeof(restorefunction) ~= "function" or typeof(getrawmetatable) ~= "function" then
			return false
		end

		local metatable = getrawmetatable(game)
		local restored = true

		if hookState.oldNamecall then
			if pcall(restorefunction, metatable.__namecall) then
				hookState.oldNamecall = nil
			else
				restored = false
			end
		end

		if hookState.oldIndex then
			if pcall(restorefunction, metatable.__index) then
				hookState.oldIndex = nil
			else
				restored = false
			end
		end

		return restored
	end

	local npcEntities = {}

	local Targeting = {
		camera = workspaceService.CurrentCamera,
		camlock = nil,
		silent = nil,
	}

	local lastEntity = {}

	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Exclude
	wallParams.IgnoreWater = true

	local fovCircles = {}

	local function makeFovCircle()
		return maid:add(FovVisual.new())
	end

	if drawingSupported then
		fovCircles.camlock = makeFovCircle()
		fovCircles.silent = makeFovCircle()
	end

	local function getFovCenter(camera)
		return Config.fovPosition or (camera.ViewportSize / 2)
	end

	function Targeting.isTeammate(entity)
		local team = entity.Team
		return team ~= nil and team == localPlayer.Team
	end

	function Targeting.isTeamTargeted(entity)
		if next(TeamTargets) == nil then
			return false
		end

		local team = entity.Team

		return team ~= nil and TeamTargets[team.Name] == true
	end

	function Targeting.entities()
		local list = {}

		if Config.targetPlayers then
			for _, player in next, playersService:GetPlayers() do
				table.insert(list, player)
			end
		end

		if Config.targetNpcs then
			for _, entity in next, npcEntities do
				table.insert(list, entity)
			end
		end

		return list
	end

	function Targeting.getCharacter(entity)
		if entity == localPlayer or PlayerLists.ignored[entity.Name] then
			return nil
		end

		if isNpc(entity) then
			local model = entity.Character

			if not model or not model.Parent or model == localPlayer.Character or playersService:GetPlayerFromCharacter(model) then
				return nil
			end
		else
			if Config.ignoreBots and entity.UserId <= 0 then
				return nil
			end

			if Config.teamCheck and Targeting.isTeammate(entity) then
				return nil
			end
		end

		local character = entity.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not humanoid or humanoid.Health <= 0 then
			return nil
		end

		if Config.forceFieldCheck and character:FindFirstChildOfClass("ForceField") then
			return nil
		end

		return character, humanoid
	end

	function Targeting.getAimParts(character, partName)
		local names = partName == "Nearest" and NEAREST_PART_NAMES or (PART_GROUPS[partName] or PART_GROUPS.Head)
		local parts = {}

		for _, name in next, names do
			local part = character:FindFirstChild(name)

			if part and part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end

		if #parts == 0 then
			local fallback = character:FindFirstChild("HumanoidRootPart")

			if fallback then
				table.insert(parts, fallback)
			end
		end

		return parts
	end

	local wallDebugLine = nil
	local targetArrowTriangle = nil

	if drawingSupported then
		wallDebugLine = maid:add(Drawing.new("Line"))
		wallDebugLine.Thickness = 2
		wallDebugLine.Visible = false

		targetArrowTriangle = maid:add(Drawing.new("Triangle"))
		targetArrowTriangle.Thickness = 1
		targetArrowTriangle.Visible = false
	end

	function Targeting.isVisible(part, character)
		local origin = Targeting.camera.CFrame.Position
		local success, result = pcall(workspaceService.Raycast, workspaceService, origin, part.Position - origin, wallParams)
		local clear = not success or result == nil or result.Instance:IsDescendantOf(character)

		if Config.wallCheckDebug and wallDebugLine then
			local point = Targeting.camera:WorldToViewportPoint(part.Position)

			wallDebugLine.From = Targeting.camera.ViewportSize / 2
			wallDebugLine.To = Vector2.new(point.X, point.Y)
			wallDebugLine.Color = clear and Color3.fromRGB(70, 220, 90) or Color3.fromRGB(255, 60, 60)
			wallDebugLine.Visible = point.Z > 0
		end

		return clear
	end

	function Targeting.predict(part)
		if not Config.predictionEnabled then
			return part.Position
		end

		local velocity = part.AssemblyLinearVelocity

		if velocity.Magnitude > MAX_PREDICTION_SPEED then
			velocity = velocity.Unit * MAX_PREDICTION_SPEED
		end

		return part.Position + Vector3.new(velocity.X * Config.predX, velocity.Y * Config.predY, velocity.Z * Config.predZ)
	end

	function Targeting.choose(entries, nearestMode)
		if #entries == 0 then
			return nil
		end

		local allVisible = true

		for _, entry in next, entries do
			if not entry.visible then
				allVisible = false
			end
		end

		local best = nil

		for _, entry in next, entries do
			local eligible = entry.visible

			if nearestMode and allVisible then
				local name = entry.part.Name
				eligible = name == "Head" or name == "UpperTorso" or name == "Torso"
			elseif not nearestMode then
				eligible = not Config.wallCheck or entry.visible
			end

			if eligible and (not best or entry.pixels < best.pixels) then
				best = entry
			end
		end

		if not best and nearestMode and not Config.wallCheck then
			for _, entry in next, entries do
				if not best or entry.pixels < best.pixels then
					best = entry
				end
			end
		end

		return best
	end

	function Targeting.select(feature)
		local camera = Targeting.camera
		local center = getFovCenter(camera)
		local partName = Config[feature .. "Part"]
		local useFov = Config[feature .. "UseFov"]
		local radius = Config[feature .. "FovRadius"]
		local limit = useFov and radius or math.huge
		local nearestMode = partName == "Nearest"
		local cameraPosition = camera.CFrame.Position
		local bestTier = math.huge
		local bestScore = math.huge
		local bestEntity = nil
		local bestPart = nil

		for _, entity in next, Targeting.entities() do
			local character, humanoid = Targeting.getCharacter(entity)

			if not character then
				continue
			end

			local entries = {}

			for _, part in next, Targeting.getAimParts(character, partName) do
				local worldDistance = (part.Position - cameraPosition).Magnitude

				if worldDistance > Config.maxDistance then
					continue
				end

				local point, onScreen = camera:WorldToViewportPoint(part.Position)

				if not onScreen and useFov then
					continue
				end

				local pixels = (Vector2.new(point.X, point.Y) - center).Magnitude

				if pixels > limit then
					continue
				end

				local visible = true

				if Config.wallCheck or nearestMode then
					visible = Targeting.isVisible(part, character)
				end

				table.insert(entries, { part = part, pixels = pixels, distance = worldDistance, visible = visible })
			end

			local chosen = Targeting.choose(entries, nearestMode)

			if not chosen then
				continue
			end

			local score = chosen.pixels

			if Config.priority == "Distance" then
				score = chosen.distance
			elseif Config.priority == "Health" then
				score = humanoid.Health
			end

			if Config.sticky and entity == lastEntity[feature] then
				score = score * 0.5
			end

			local preferred = not isNpc(entity) and (PlayerLists.targeted[entity.Name] or Targeting.isTeamTargeted(entity))
			local tier = preferred and 0 or 1

			if tier < bestTier or (tier == bestTier and score < bestScore) then
				bestTier = tier
				bestScore = score
				bestEntity = entity
				bestPart = chosen.part
			end
		end

		lastEntity[feature] = bestEntity

		if not bestPart then
			return nil
		end

		local position = Targeting.predict(bestPart)

		local minDot = math.cos(math.rad(89))

		if useFov then
			local focal = (camera.ViewportSize.Y / 2) / math.tan(math.rad(camera.FieldOfView) / 2)
			local maxAngle = math.atan(radius / focal) * 1.5 + math.rad(4)
			minDot = math.cos(math.min(maxAngle, math.rad(89)))
		end

		return { entity = bestEntity, part = bestPart, position = position, minDot = minDot }
	end

	function Targeting.updateCircles(camera)
		local center = getFovCenter(camera)

		for feature, visual in next, fovCircles do
			local enabled = (feature == "camlock" and Config.camlock) or (feature == "silent" and Config.silentAim)

			visual:update(enabled and Config[feature .. "UseFov"] and Config[feature .. "FovShow"], center, Config[feature .. "FovRadius"], Config[feature .. "FovColor"], Config[feature .. "FovFilled"], Config.fovOpacity, Config.fovRainbow)
		end

		if wallDebugLine and not Config.wallCheckDebug then
			wallDebugLine.Visible = false
		end
	end

	function Targeting.update()
		local camera = workspaceService.CurrentCamera
		Targeting.camera = camera
		Targeting.camlock = nil
		Targeting.silent = nil

		Targeting.updateCircles(camera)

		if not Config.camlock then
			lastEntity.camlock = nil
		end

		if not Config.silentAim then
			lastEntity.silent = nil
		end

		if not Config.camlock and not Config.silentAim then
			return
		end

		wallParams.FilterDescendantsInstances = { localPlayer.Character }

		if Config.camlock then
			Targeting.camlock = Targeting.select("camlock")
		end

		if Config.silentAim then
			Targeting.silent = Targeting.select("silent")
		end

		if targetArrowTriangle then
			local arrowTarget = Targeting.camlock or Targeting.silent

			if Config.targetArrow and arrowTarget then
				updateArrow(targetArrowTriangle, camera, arrowTarget.position, THEME.accent)
			else
				targetArrowTriangle.Visible = false
			end
		end
	end

	local fovDragging = false
	local fovDragOffset = Vector2.new()

	local function visibleFovRadius()
		local radius = nil

		if Config.camlock and Config.camlockUseFov and Config.camlockFovShow then
			radius = Config.camlockFovRadius
		end

		if Config.silentAim and Config.silentUseFov and Config.silentFovShow then
			radius = math.max(radius or 0, Config.silentFovRadius)
		end

		return radius
	end

	maid:add(userInputService.InputBegan:Connect(function(input, processed)
		local radius = visibleFovRadius()

		if processed or not Config.movableFov or not radius then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local center = getFovCenter(Targeting.camera)
		local position = Vector2.new(input.Position.X, input.Position.Y)

		if (position - center).Magnitude > radius + 30 then
			return
		end

		fovDragging = true
		fovDragOffset = center - position

		local connection = nil

		connection = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				fovDragging = false
				connection:Disconnect()
			end
		end)

		maid:add(connection)
	end))

	maid:add(userInputService.InputChanged:Connect(function(input)
		if not fovDragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		Config.fovPosition = Vector2.new(input.Position.X, input.Position.Y) + fovDragOffset
	end))

	local Hitbox = { expanded = {} }

	function Hitbox.parts(character)
		local parts = {}
		local seen = {}

		for _, partName in next, { Config.camlockPart, Config.silentPart } do
			for _, name in next, PART_GROUPS[partName] or { "HumanoidRootPart" } do
				local part = character:FindFirstChild(name)

				if part and part:IsA("BasePart") and not seen[part] then
					seen[part] = true
					table.insert(parts, part)
				end
			end
		end

		return parts
	end

	function Hitbox.restore(part, data)
		if part.Parent then
			part.Size = data.size
			part.CanCollide = data.canCollide
		end
	end

	function Hitbox.restoreAll()
		for part, data in next, Hitbox.expanded do
			Hitbox.restore(part, data)
			Hitbox.expanded[part] = nil
		end
	end

	function Hitbox.update()
		local active = Config.hitboxExpander and (Config.silentAim or Config.camlock or Config.triggerbot)

		if not active then
			if next(Hitbox.expanded) then
				Hitbox.restoreAll()
			end

			return
		end

		local size = Vector3.new(Config.hitboxSize, Config.hitboxSize, Config.hitboxSize)
		local seen = {}

		for _, entity in next, Targeting.entities() do
			local character = Targeting.getCharacter(entity)

			if not character then
				continue
			end

			for _, part in next, Hitbox.parts(character) do
				seen[part] = true

				if not Hitbox.expanded[part] then
					Hitbox.expanded[part] = { size = part.Size, canCollide = part.CanCollide }
					part.CanCollide = false
				end

				if part.Size ~= size then
					part.Size = size
				end
			end
		end

		for part, data in next, Hitbox.expanded do
			if not seen[part] then
				Hitbox.restore(part, data)
				Hitbox.expanded[part] = nil
			end
		end
	end

	local Spectate = { player = nil }

	function Spectate.stop()
		Spectate.player = nil

		local camera = workspaceService.CurrentCamera
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if camera and humanoid then
			camera.CameraSubject = humanoid
		end
	end

	function Spectate.update()
		local player = Spectate.player

		if not player then
			return
		end

		local camera = workspaceService.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if camera and humanoid and camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
	end

	local flingCancel = false

	local function flingTargets(list, label)
		if busy then
			return
		end

		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not root or not humanoid then
			notify("Your character is not loaded.")
			return
		end

		if #list == 0 then
			notify(label .. ": nobody to fling.")
			return
		end

		busy = true
		flingCancel = false

		local home = root.CFrame
		local savedProperties = root.CustomPhysicalProperties
		local changedParts = {}

		humanoid.PlatformStand = true
		root.CustomPhysicalProperties = PhysicalProperties.new(100, 0.3, 0.5)

		for _, descendant in next, character:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= root and descendant.CanCollide then
				descendant.CanCollide = false
				changedParts[descendant] = true
			end
		end

		local angular = Instance.new("BodyAngularVelocity")
		angular.AngularVelocity = Vector3.new(0, 99999, 0)
		angular.MaxTorque = Vector3.new(0, math.huge, 0)
		angular.P = math.huge
		angular.Parent = root

		local flung = 0
		local flip = false
		local angle = 0
		local spin = 0

		for _, player in next, list do
			if not alive or flingCancel or not root.Parent then
				break
			end

			local startedAt = os.clock()

			while alive and not flingCancel and root.Parent and os.clock() - startedAt < FLING_TIMEOUT do
				local targetCharacter = player.Character
				local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
				local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")

				if not player.Parent or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
					break
				end

				if targetRoot.AssemblyLinearVelocity.Magnitude > FLING_SUCCESS_SPEED then
					flung += 1
					break
				end

				local center = targetRoot.Position + targetRoot.AssemblyLinearVelocity * 0.1
				local radius = Config.flingRadius * (0.5 + 0.5 * math.sin(angle * 0.45))
				local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle * 1.7) * 1.2, math.sin(angle) * radius)

				root.CFrame = CFrame.new(center + offset) * CFrame.Angles(0, spin, 0)
				flip = not flip
				root.AssemblyLinearVelocity = flip and Vector3.new(1e4, 1e4, 1e4) or Vector3.zero
				root.AssemblyAngularVelocity = Vector3.new(0, 1e5, 0)

				local deltaTime = runService.Heartbeat:Wait()
				angle += Config.flingSpeed * deltaTime
				spin += 90 * deltaTime
			end
		end

		angular:Destroy()

		for part in next, changedParts do
			if part.Parent then
				part.CanCollide = true
			end
		end

		humanoid.PlatformStand = false

		if root.Parent then
			root.CustomPhysicalProperties = savedProperties

			if Config.flingReturn then
				root.CFrame = home
			end

			for _ = 1, 15 do
				if not root.Parent then
					break
				end

				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				runService.Heartbeat:Wait()
			end
		end

		busy = false
		notify(string.format("%s: %d flung.", label, flung))
	end

	local function isCore()
		if typeof(getcallingscript) ~= "function" then
			return false
		end

		local success, caller = pcall(getcallingscript)

		while success and caller do
			if caller.Name == "PlayerModule" then
				return true
			end

			caller = caller.Parent
		end

		return false
	end

	local function canRedirect()
		if checkcaller() then
			return false
		end

		return not isCore()
	end

	local function redirect(target, origin, direction)
		local delta = target.position - origin
		local deltaLength = delta.Magnitude
		local directionLength = direction.Magnitude

		if deltaLength < 0.001 or directionLength < 0.001 then
			return nil
		end

		local dot = (delta.X * direction.X + delta.Y * direction.Y + delta.Z * direction.Z) / (deltaLength * directionLength)

		if dot < target.minDot then
			return nil
		end

		return delta / deltaLength * directionLength
	end

	local function onNamecall(method, self, ...)
		local oldNamecall = hookState.oldNamecall
		local camera = Targeting.camera
		local target = Targeting.silent

		if not alive or not Config.silentAim or not target or (self ~= workspaceService and self ~= camera) then
			return oldNamecall(self, ...)
		end

		if self == workspaceService then
			if method == "Raycast" then
				local origin, direction = ...

				if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
					local redirected = redirect(target, origin, direction)

					if redirected and canRedirect() then
						setNamecall(method)
						return oldNamecall(self, origin, redirected, select(3, ...))
					end
				end
			elseif LEGACY_RAY_METHODS[method] then
				local ray = ...

				if typeof(ray) == "Ray" then
					local redirected = redirect(target, ray.Origin, ray.Direction)

					if redirected and canRedirect() then
						setNamecall(method)
						return oldNamecall(self, Ray.new(ray.Origin, redirected), select(2, ...))
					end
				end
			end
		elseif SCREEN_RAY_METHODS[method] then
			local ray = oldNamecall(self, ...)

			if typeof(ray) ~= "Ray" then
				return ray
			end

			local redirected = redirect(target, ray.Origin, ray.Direction)

			if redirected and canRedirect() then
				return Ray.new(ray.Origin, redirected)
			end

			return ray
		end

		setNamecall(method)
		return oldNamecall(self, ...)
	end

	local function onIndex(self, key)
		local target = Targeting.silent

		if self == mouse and MOUSE_KEYS[key] and alive and Config.silentAim and target and canRedirect() then
			if key == "Hit" then
				return CFrame.new(target.position)
			end

			if key == "Target" then
				return target.part
			end

			local origin = Targeting.camera.CFrame.Position
			return Ray.new(origin, (target.position - origin).Unit)
		end

		return hookState.oldIndex(self, key)
	end

	local function applyHooks()
		if typeof(hookmetamethod) ~= "function" or typeof(newcclosure) ~= "function" or typeof(getnamecallmethod) ~= "function" or typeof(checkcaller) ~= "function" then
			return false, "executor is missing hookmetamethod, newcclosure, getnamecallmethod or checkcaller"
		end

		local success, message = pcall(HookManager.hookNamecall)

		if not success then
			return false, tostring(message)
		end

		hookState.namecall = onNamecall

		local indexSuccess, indexMessage = pcall(HookManager.hookIndex)

		if indexSuccess then
			hookState.index = onIndex
		else
			notify("Mouse hook unavailable: " .. tostring(indexMessage))
		end

		return true
	end

	local camlockBind = { Key = Config.camlockKey }
	local camlockToggled = false

	local function keyMatches(key, input)
		if typeof(key) ~= "EnumItem" then
			return false
		end

		if key.EnumType == Enum.KeyCode then
			return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key
		end

		return input.UserInputType == key
	end

	local function isKeyDown(key)
		if typeof(key) ~= "EnumItem" or userInputService:GetFocusedTextBox() then
			return false
		end

		if key.EnumType == Enum.KeyCode then
			return userInputService:IsKeyDown(key)
		end

		return userInputService:IsMouseButtonPressed(key)
	end

	maid:add(userInputService.InputBegan:Connect(function(input, processed)
		if processed or Config.camlockMode ~= "Toggle" then
			return
		end

		if keyMatches(Config.camlockKey, input) then
			camlockToggled = not camlockToggled
		end
	end))

	local function isCamlockActive()
		if Config.camlockMode == "Always" then
			return true
		end

		if Config.camlockMode == "Hold" then
			return isKeyDown(Config.camlockKey)
		end

		return camlockToggled
	end

	local function updateCamlock()
		local target = Targeting.camlock

		if not Config.camlock or not target or not isCamlockActive() then
			return
		end

		local camera = Targeting.camera
		local goal = CFrame.new(camera.CFrame.Position, target.position)

		camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(Config.camlockSmoothing, 0.01, 1))
	end

	local triggerParams = RaycastParams.new()
	triggerParams.FilterType = Enum.RaycastFilterType.Exclude
	triggerParams.IgnoreWater = true

	local virtualInput = nil

	pcall(function()
		virtualInput = game:GetService("VirtualInputManager")
	end)

	local clickMethods = {
		function()
			mouse1click()
		end,
		function()
			mouse1press()
			task.wait()
			mouse1release()
		end,
		function()
			local center = Targeting.camera.ViewportSize / 2
			virtualInput:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
			task.wait()
			virtualInput:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
		end,
	}

	local clickMethod = nil
	local clickFailed = false
	local lastShot = 0

	local function click()
		task.spawn(function()
			if clickMethod then
				pcall(clickMethods[clickMethod])
				return
			end

			for index, method in next, clickMethods do
				if pcall(method) then
					clickMethod = index
					return
				end
			end

			if not clickFailed then
				clickFailed = true
				notify("Triggerbot could not click with any method.")
			end
		end)
	end

	local function getEntityFromPart(part)
		local current = part

		while current and current ~= workspaceService do
			if Config.targetPlayers then
				local player = playersService:GetPlayerFromCharacter(current)

				if player then
					return player
				end
			end

			if Config.targetNpcs and npcEntities[current] then
				return npcEntities[current]
			end

			current = current.Parent
		end

		return nil
	end

	local function updateTrigger()
		if not Config.triggerbot or os.clock() - lastShot < Config.triggerDelay then
			return
		end

		if userInputService:GetFocusedTextBox() then
			return
		end

		local camera = Targeting.camera
		local center = camera.ViewportSize / 2

		triggerParams.FilterDescendantsInstances = { localPlayer.Character }

		local rayCreated, ray = pcall(camera.ViewportPointToRay, camera, center.X, center.Y)

		if not rayCreated then
			return
		end

		local success, result = pcall(workspaceService.Raycast, workspaceService, ray.Origin, ray.Direction * 1000, triggerParams)

		if not success or not result then
			return
		end

		local entity = getEntityFromPart(result.Instance)

		if not entity or not Targeting.getCharacter(entity) then
			return
		end

		lastShot = os.clock()
		click()
	end

	local Esp = { all = {} }
	Esp.__index = Esp

	local espSettings = {
		outline = true,
		boxes = false,
		names = false,
		skeleton = false,
		tracers = false,
		health = false,
		color = Color3.new(1, 1, 1),
		skeletonColor = Color3.new(1, 1, 1),
	}

	local enemyTeamColors = {}

	local function refreshEnemyTeamColors()
		table.clear(enemyTeamColors)

		if not Config.autoTeamColors then
			return
		end

		local index = 0

		for _, team in next, teamsService:GetTeams() do
			if team ~= localPlayer.Team then
				index += 1

				if index == 1 then
					enemyTeamColors[team] = Config.enemyTeamColor1
				elseif index == 2 then
					enemyTeamColors[team] = Config.enemyTeamColor2
				else
					enemyTeamColors[team] = EXTRA_TEAM_COLORS[(index - 3) % #EXTRA_TEAM_COLORS + 1]
				end
			end
		end
	end

	local function getEspColors(player)
		if Targeting.isTeammate(player) then
			local color = Config.teammateColor

			if Config.teammateUseGameColor and player.Team then
				color = player.Team.TeamColor.Color
			end

			return color, color
		end

		if Config.autoTeamColors and player.Team then
			local color = enemyTeamColors[player.Team]

			if color then
				return color, color
			end
		end

		return Config.boxColor, Config.skeletonColor
	end

	local function projectWorld(position)
		local point = workspaceService.CurrentCamera:WorldToViewportPoint(position)

		if point.Z <= 0 then
			return nil
		end

		return Vector2.new(point.X, point.Y)
	end

	function Esp.new(player)
		local self = setmetatable({}, Esp)
		self.player = player
		self.lines = {}
		self.label = nil
		self.character = nil
		self.humanoid = nil

		Esp.all[player] = self

		return self
	end

	function Esp:getLine(index)
		local line = self.lines[index]

		if not line then
			line = Drawing.new("Line")
			line.Transparency = 1
			line.Visible = false
			self.lines[index] = line
		end

		return line
	end

	function Esp:getLabel()
		if not self.label then
			local text = Drawing.new("Text")
			text.Center = true
			text.Outline = true
			text.Size = 13
			text.Visible = false
			self.label = text
		end

		return self.label
	end

	function Esp:hideLines(fromIndex)
		for index = fromIndex, #self.lines do
			self.lines[index].Visible = false
		end
	end

	function Esp:hideAll()
		self:hideLines(1)

		if self.label then
			self.label.Visible = false
		end
	end

	function Esp:update()
		local character = self.player.Character

		if character ~= self.character then
			self.character = character
			self.humanoid = nil
		end

		if character and not self.humanoid then
			self.humanoid = character:FindFirstChildOfClass("Humanoid")
		end

		local humanoid = self.humanoid
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspaceService.CurrentCamera

		if not Config.esp or not camera or not humanoid or not root or humanoid.Health <= 0 then
			self:hideAll()
			return
		end

		if isNpc(self.player) then
			if not Config.espNpcs then
				self:hideAll()
				return
			end
		elseif Config.ignoreBots and self.player.UserId <= 0 then
			self:hideAll()
			return
		end

		if PlayerLists.ignored[self.player.Name] then
			self:hideAll()
			return
		end

		if Config.hideTeammates and Targeting.isTeammate(self.player) then
			self:hideAll()
			return
		end

		local distance = (root.Position - camera.CFrame.Position).Magnitude

		if distance > Config.espMaxDistance then
			self:hideAll()
			return
		end

		espSettings.color, espSettings.skeletonColor = getEspColors(self.player)

		local tracerOrigin = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
		local healthFraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		local segments, bounds = computeShapes(character, projectWorld, espSettings, healthFraction, tracerOrigin)

		for index, segment in next, segments do
			local line = self:getLine(index)
			line.From = segment[1]
			line.To = segment[2]
			line.Color = segment[3]
			line.Thickness = segment[4]
			line.ZIndex = index
			line.Visible = true
		end

		self:hideLines(#segments + 1)

		if espSettings.names and bounds then
			local text = ""

			if Config.espNames then
				text = self.player.Name
			end

			if Config.espDistance then
				text = text .. (text ~= "" and " " or "") .. string.format("[%dm]", math.floor(distance))
			end

			local label = self:getLabel()
			label.Text = text
			label.Color = espSettings.color
			label.Position = Vector2.new((bounds.left + bounds.right) / 2, bounds.top - 16)
			label.Visible = text ~= ""
		elseif self.label then
			self.label.Visible = false
		end
	end

	function Esp:destroy()
		for _, line in next, self.lines do
			pcall(function()
				line:Remove()
			end)
		end

		self.lines = {}

		if self.label then
			pcall(function()
				self.label:Remove()
			end)

			self.label = nil
		end

		Esp.all[self.player] = nil
	end

	function Esp.updateAll()
		espSettings.outline = Config.espOutline
		espSettings.boxes = Config.espBoxes
		espSettings.names = Config.espNames or Config.espDistance
		espSettings.skeleton = Config.espSkeleton and not performanceActive
		espSettings.tracers = Config.espTracers and not performanceActive
		espSettings.health = Config.espHealth

		refreshEnemyTeamColors()

		for _, esp in next, Esp.all do
			esp:update()
		end
	end

	local function addPlayer(player)
		if player ~= localPlayer and not Esp.all[player] then
			Esp.new(player)
		end
	end

	local function removePlayer(player)
		local esp = Esp.all[player]

		if esp then
			esp:destroy()
		end

		if Spectate.player == player then
			Spectate.stop()
		end

		if selectedPlayer == player.Name then
			selectedPlayer = nil
		end
	end

	local npcTracking = false

	local function registerNpc(humanoid)
		local model = humanoid.Parent

		if not model or not model:IsA("Model") or npcEntities[model] then
			return
		end

		if model == localPlayer.Character or playersService:GetPlayerFromCharacter(model) then
			return
		end

		local entity = { Character = model, Name = model.Name, UserId = 0, Team = nil }
		npcEntities[model] = entity

		if drawingSupported then
			Esp.new(entity)
		end
	end

	local function unregisterNpc(model)
		local entity = model and npcEntities[model]

		if not entity then
			return
		end

		npcEntities[model] = nil

		local esp = Esp.all[entity]

		if esp then
			esp:destroy()
		end
	end

	local function ensureNpcTracking()
		if npcTracking then
			return
		end

		npcTracking = true

		for _, descendant in next, workspaceService:GetDescendants() do
			if descendant:IsA("Humanoid") then
				registerNpc(descendant)
			end
		end

		maid:add(workspaceService.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Humanoid") then
				task.delay(0.3, function()
					if alive and descendant.Parent then
						registerNpc(descendant)
					end
				end)
			end
		end))

		maid:add(workspaceService.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("Humanoid") then
				unregisterNpc(descendant.Parent)
			end
		end))
	end

	local function cleanup()
		if not alive then
			return
		end

		alive = false
		showToast = nil
		flingCancel = true
		setAntiAfk(false)
		stopFly()

		for part in next, noclipParts do
			if part.Parent then
				part.CanCollide = true
			end
		end

		Spectate.stop()

		for _, name in next, RENDER_BINDS do
			pcall(runService.UnbindFromRenderStep, runService, name)
		end

		Hitbox.restoreAll()
		maid:clean()

		for _, esp in next, table.clone(Esp.all) do
			esp:destroy()
		end

		for _, connection in next, connections do
			connection:Disconnect()
		end

		local restored = HookManager.remove()

		ui.destroy()

		shared.Magma = nil
		warn(restored and "[magma] Unloaded, hooks restored." or "[magma] Unloaded, hooks left inert.")
	end

	shared.Magma = { unload = cleanup }

	local antiAfkConnection = nil

	function setAntiAfk(enabled)
		if antiAfkConnection then
			antiAfkConnection:Disconnect()
			antiAfkConnection = nil
		end

		if not enabled then
			return
		end

		local virtualUser = game:GetService("VirtualUser")

		antiAfkConnection = localPlayer.Idled:Connect(function()
			pcall(function()
				virtualUser:CaptureController()
				virtualUser:ClickButton2(Vector2.new())
			end)
		end)
	end

	local watermark = make("TextLabel", {
		Name = "Watermark",
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.fromOffset(190, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Text = "magma",
		TextColor3 = THEME.textBright,
		TextSize = 11,
		Font = FONT_BOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Active = true,
		ZIndex = 6,
		Parent = ui.gui,
	})

	round(watermark, 8)
	addStroke(watermark, THEME.accentDark)

	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(26, 17, 22), Color3.fromRGB(11, 11, 14)),
		Rotation = 90,
		Parent = watermark,
	})

	local smoothedFps = 60
	local lastUtilityTick = 0

	local function updateUtility(deltaTime)
		if deltaTime and deltaTime > 0 then
			smoothedFps = smoothedFps * 0.9 + (1 / deltaTime) * 0.1
		end

		performanceActive = Config.performanceMode or (Config.performanceAuto and smoothedFps < Config.performanceThreshold)

		watermark.Visible = Config.showWatermark

		if not Config.showWatermark or os.clock() - lastUtilityTick < 0.3 then
			return
		end

		lastUtilityTick = os.clock()

		local pingText = "-- ms"

		local pingSuccess, pingValue = pcall(function()
			return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
		end)

		if pingSuccess and typeof(pingValue) == "number" then
			pingText = string.format("%d ms", math.floor(pingValue + 0.5))
		end

		watermark.Text = string.format("magma | %d fps | %s", math.floor(smoothedFps + 0.5), pingText)

		for _, entry in next, ui.keybindRegistry do
			if entry.display then
				entry.display:SetText(entry.label .. ":  " .. entry.bind.Describe(entry.bind.Key))
			end
		end
	end

	maid:add(runService.RenderStepped:Connect(protect("Utility", updateUtility)))

	local function updateNoclip()
		local character = localPlayer.Character

		if not Config.noclip or not character then
			for part in next, noclipParts do
				if part.Parent then
					part.CanCollide = true
				end

				noclipParts[part] = nil
			end

			return
		end

		for _, part in next, character:GetChildren() do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
				noclipParts[part] = true
			end
		end
	end

	maid:add(runService.Stepped:Connect(protect("Noclip", updateNoclip)))

	local flyBodyVelocity = nil

	function stopFly()
		if flyBodyVelocity then
			flyBodyVelocity:Destroy()
			flyBodyVelocity = nil
		end

		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid.PlatformStand = false
		end
	end

	local function updateMovement()
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if not character or not humanoid or not root then
			stopFly()
			return
		end

		if Config.walkSpeedEnabled then
			humanoid.WalkSpeed = Config.walkSpeedValue
		end

		if not Config.fly then
			if flyBodyVelocity then
				stopFly()
			end

			return
		end

		if not flyBodyVelocity or flyBodyVelocity.Parent ~= root then
			flyBodyVelocity = Instance.new("BodyVelocity")
			flyBodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
			flyBodyVelocity.Velocity = Vector3.zero
			flyBodyVelocity.Parent = root
		end

		local horizontal = humanoid.MoveDirection * Config.flySpeed
		local ascending = humanoid.Jump or userInputService:IsKeyDown(Enum.KeyCode.Space)

		if ascending then
			flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			flyBodyVelocity.Velocity = Vector3.new(horizontal.X, Config.flySpeed, horizontal.Z)
		else
			flyBodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
			flyBodyVelocity.Velocity = Vector3.new(horizontal.X, 0, horizontal.Z)
		end
	end

	maid:add(runService.Heartbeat:Connect(protect("Movement", updateMovement)))

	maid:add(userInputService.JumpRequest:Connect(function()
		if not Config.infiniteJump then
			return
		end

		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end))

	local Controls = {}

	local function addToggle(section, key, text, onChange, options)
		local toggle = section:AddToggle(text, Config[key], function(value)
			Config[key] = value

			if onChange then
				onChange(value)
			end
		end, options)

		Controls[key] = { control = toggle, kind = "value" }

		return toggle
	end

	local function addSlider(section, key, text, minimum, maximum, rounding, suffix)
		local slider = section:AddSlider(text, minimum, maximum, Config[key], rounding, function(value)
			Config[key] = value
		end, { suffix = suffix })

		Controls[key] = { control = slider, kind = "value" }

		return slider
	end

	local function addDropdown(section, key, text, values)
		local dropdown = section:AddDropdown(text, values, Config[key], function(value)
			if value then
				Config[key] = value
			end
		end)

		Controls[key] = { control = dropdown, kind = "value" }

		return dropdown
	end

	local function addColor(section, key, text)
		local color = section:AddColor(text, Config[key], function(value)
			Config[key] = value
		end)

		Controls[key] = { control = color, kind = "color" }

		return color
	end

	local function formatNumber(value)
		return tostring(math.floor(value * 1000 + 0.5) / 1000)
	end

	local function addPredictionControl(section, key, text)
		local slider = nil
		local input = nil

		slider = section:AddSlider(text, 0, 1, Config[key], 2, function(value)
			Config[key] = value
			input:Set(formatNumber(value), true)
		end)

		input = section:AddInput(text .. " (type)", formatNumber(Config[key]), function(typed)
			local number = tonumber(typed)

			if number then
				number = math.clamp(number, 0, 10)
				Config[key] = number
				slider:Set(math.clamp(number, 0, 1), true)
			end

			input:Set(formatNumber(Config[key]), true)
		end, "0 to 10")

		Controls[key] = { control = slider, kind = "value" }
	end

	local placeFolder = CONFIG_FOLDER .. "/" .. tostring(game.PlaceId)
	local autoloadPath = placeFolder .. "/autoload.txt"

	local filesSupported = pcall(function()
		if not isfolder("Magma") then
			makefolder("Magma")
		end

		if not isfolder(CONFIG_FOLDER) then
			makefolder(CONFIG_FOLDER)
		end

		if not isfolder(placeFolder) then
			makefolder(placeFolder)
		end
	end)

	local selectedConfigName = ""
	local configNameInput = nil
	local configListDropdown = nil

	local function configPath(name)
		return placeFolder .. "/" .. name .. ".json"
	end

	local function listConfigNames()
		local names = {}

		if not filesSupported then
			return names
		end

		local success, files = pcall(listfiles, placeFolder)

		if not success then
			return names
		end

		for _, path in next, files do
			local name = string.match(path, "([^/\\]+)%.json$")

			if name then
				table.insert(names, name)
			end
		end

		table.sort(names)

		return names
	end

	local function refreshConfigList()
		if configListDropdown then
			configListDropdown:SetValues(listConfigNames())
		end
	end

	local function applyConfigData(data)
		for key, value in next, data do
			local entry = Controls[key]

			if entry then
				if type(value) == "table" and value.r and value.g and value.b then
					value = Color3.new(value.r, value.g, value.b)
				end

				Config[key] = value

				pcall(function()
					entry.control:Set(value, true)
				end)
			end
		end
	end

	local function saveConfig()
		if not filesSupported then
			notify("Your executor has no file API, so configs cannot be saved.")
			return
		end

		if selectedConfigName == "" then
			notify("Type a config name first.")
			return
		end

		local copy = {}

		for key in next, Controls do
			local value = Config[key]

			if typeof(value) == "Color3" then
				copy[key] = { r = value.R, g = value.G, b = value.B }
			else
				copy[key] = value
			end
		end

		local encoded, result = pcall(function()
			return httpService:JSONEncode(copy)
		end)

		if not encoded then
			notify("Could not encode the config.")
			return
		end

		if pcall(writefile, configPath(selectedConfigName), result) then
			notify("Saved \"" .. selectedConfigName .. "\".")
			refreshConfigList()
		else
			notify("Could not write the config file.")
		end
	end

	local function loadConfig()
		if not filesSupported or selectedConfigName == "" then
			notify("Type or pick a config name first.")
			return
		end

		local readSuccess, content = pcall(readfile, configPath(selectedConfigName))

		if not readSuccess then
			notify("Could not read \"" .. selectedConfigName .. "\".")
			return
		end

		local decoded, data = pcall(function()
			return httpService:JSONDecode(content)
		end)

		if not decoded or type(data) ~= "table" then
			notify("That config file is invalid.")
			return
		end

		applyConfigData(data)
		notify("Loaded \"" .. selectedConfigName .. "\".")
	end

	local function deleteConfig()
		if not filesSupported or selectedConfigName == "" then
			return
		end

		pcall(delfile, configPath(selectedConfigName))
		notify("Deleted \"" .. selectedConfigName .. "\".")
		refreshConfigList()
	end

	local function getPlayerNames()
		local names = {}

		for _, player in next, playersService:GetPlayers() do
			if player ~= localPlayer then
				table.insert(names, player.Name)
			end
		end

		table.sort(names)

		return names
	end

	local function getTeamNames()
		local names = {}

		for _, team in next, teamsService:GetTeams() do
			table.insert(names, team.Name)
		end

		return names
	end

	local function setListFromDropdown(target, value)
		table.clear(target)

		if type(value) ~= "table" then
			return
		end

		for name, enabled in next, value do
			if enabled then
				target[name] = true
			end
		end
	end

	local combatTab = addTab("Combat")
	local visualsTab = addTab("Visuals")
	local playersTab = addTab("Players")
	local miscTab = addTab("Misc")
	local menuTab = addTab("Menu")

	safe("Combat tab", function()
		local hitParts = { "Head", "HumanoidRootPart", "Torso", "Feet", "Left Leg", "Right Leg", "Both Legs", "Nearest" }

		local camlockSection = combatTab:AddSection("Camlock", 1)
		addToggle(camlockSection, "camlock", "Camlock")
		addDropdown(camlockSection, "camlockMode", "Mode", { "Always", "Hold", "Toggle" })

		camlockSection:AddKeybind("Camlock Key", Config.camlockKey, function(key)
			Config.camlockKey = key
		end)

		addSlider(camlockSection, "camlockSmoothing", "Sensitivity", 0.01, 1, 2)
		addDropdown(camlockSection, "camlockPart", "Hit Part", hitParts)
		addToggle(camlockSection, "camlockUseFov", "Use FOV")

		local silentSection = combatTab:AddSection("Silent Aim", 1)
		local silentToggle = nil

		silentToggle = addToggle(silentSection, "silentAim", "Silent Aim", function(value)
			if not value then
				return
			end

			local success, reason = applyHooks()

			if success then
				return
			end

			Config.silentAim = false
			notify("Silent aim unavailable: " .. tostring(reason))
			silentToggle:Set(false, true)
		end)

		addDropdown(silentSection, "silentPart", "Hit Part", hitParts)
		addToggle(silentSection, "silentUseFov", "Use FOV")
		silentSection:AddLabel("Redirects your shots to the target picked by the settings on this tab. FOV circle settings are in Visuals.", { wrap = true })

		local triggerSection = combatTab:AddSection("Triggerbot", 1)
		addToggle(triggerSection, "triggerbot", "Triggerbot")
		addSlider(triggerSection, "triggerDelay", "Delay", 0, 2, 2, " s")
		triggerSection:AddLabel("Clicks for you when your crosshair is on a valid target.", { wrap = true })

		local targetSection = combatTab:AddSection("Targeting", 2)
		addToggle(targetSection, "targetPlayers", "Target Players")

		addToggle(targetSection, "targetNpcs", "Target NPCs", function(value)
			if value then
				ensureNpcTracking()
			end
		end, { tooltip = "NPC check: also aims at and triggers on NPCs, which are non-player characters." })

		addDropdown(targetSection, "priority", "Priority", { "Center", "Distance", "Health" })
		addSlider(targetSection, "maxDistance", "Max Distance", 50, 10000, 0, " st")
		addToggle(targetSection, "sticky", "Sticky Target")
		targetSection:AddLabel("Nearest hits the visible part closest to your crosshair, and picks between head and torso when they are fully in the open.", { wrap = true })

		local checkSection = combatTab:AddSection("Checks", 2)
		addToggle(checkSection, "teamCheck", "Team Check")
		addToggle(checkSection, "wallCheck", "Wall Check")
		addToggle(checkSection, "forceFieldCheck", "Ignore ForceField")
		addToggle(checkSection, "ignoreBots", "Ignore Bots")

		local predictionSection = combatTab:AddSection("Prediction", 2)
		addToggle(predictionSection, "predictionEnabled", "Prediction")
		addPredictionControl(predictionSection, "predX", "Prediction X")
		addPredictionControl(predictionSection, "predY", "Prediction Y")
		addPredictionControl(predictionSection, "predZ", "Prediction Z")

		local hitboxSection = combatTab:AddSection("Hitbox Expander", 2)
		addToggle(hitboxSection, "hitboxExpander", "Hitbox Expander")
		addSlider(hitboxSection, "hitboxSize", "Hitbox Size", 1, 50, 0)
	end)

	safe("Visuals tab", function()
		local espSection = visualsTab:AddSection("ESP", 1)
		addToggle(espSection, "esp", "Enable ESP")
		addToggle(espSection, "espNpcs", "Show NPCs", function(value)
			if value then
				ensureNpcTracking()
			end
		end)

		addToggle(espSection, "espBoxes", "Boxes")
		addToggle(espSection, "espOutline", "Box Outline")
		addToggle(espSection, "espNames", "Names")
		addToggle(espSection, "espDistance", "Distance")
		addToggle(espSection, "espSkeleton", "Skeleton")
		addToggle(espSection, "espTracers", "Tracers")
		addToggle(espSection, "espHealth", "Health Bar")
		addToggle(espSection, "hideTeammates", "Hide Teammates")
		addSlider(espSection, "espMaxDistance", "Range", 50, 10000, 0, " st")

		local camlockFovSection = visualsTab:AddSection("Camlock FOV", 1)
		addSlider(camlockFovSection, "camlockFovRadius", "FOV Radius", 10, 1000, 0, " px")
		addToggle(camlockFovSection, "camlockFovShow", "Show FOV Circle")
		addToggle(camlockFovSection, "camlockFovFilled", "Filled FOV")
		addColor(camlockFovSection, "camlockFovColor", "FOV Color")

		local silentFovSection = visualsTab:AddSection("Silent FOV", 1)
		addSlider(silentFovSection, "silentFovRadius", "FOV Radius", 10, 1000, 0, " px")
		addToggle(silentFovSection, "silentFovShow", "Show FOV Circle")
		addToggle(silentFovSection, "silentFovFilled", "Filled FOV")
		addColor(silentFovSection, "silentFovColor", "FOV Color")

		local colorSection = visualsTab:AddSection("Colors", 2)
		addColor(colorSection, "boxColor", "Box Color")
		addColor(colorSection, "skeletonColor", "Skeleton Color")
		addToggle(colorSection, "autoTeamColors", "Auto Team Colors")
		addColor(colorSection, "enemyTeamColor1", "Enemy Team 1")
		addColor(colorSection, "enemyTeamColor2", "Enemy Team 2")
		addToggle(colorSection, "teammateUseGameColor", "Game Team Color")
		addColor(colorSection, "teammateColor", "Teammate Color")

		local fovSection = visualsTab:AddSection("FOV Settings", 2)
		addSlider(fovSection, "fovOpacity", "Filled Opacity", 0.05, 1, 2)
		addToggle(fovSection, "fovRainbow", "Rainbow FOV")
		addToggle(fovSection, "targetArrow", "Target Arrow")
		addToggle(fovSection, "movableFov", "Movable FOV")
		addToggle(fovSection, "wallCheckDebug", "Debug Wall Check")

		fovSection:AddButton("Reset FOV Position", function()
			Config.fovPosition = nil
		end)

		fovSection:AddLabel("With Movable FOV on, drag inside a circle to move both circles.", { wrap = true })
	end)

	safe("Players tab", function()
		local playerSection = playersTab:AddSection("Player", 1)

		local playerDropdown = playerSection:AddDropdown("Player", getPlayerNames(), nil, function(value)
			selectedPlayer = value
		end)

		playerSection:AddButton("Spectate / Stop", function()
			local player = selectedPlayer and playersService:FindFirstChild(selectedPlayer)

			if Spectate.player then
				Spectate.stop()
				notify("Stopped spectating.")
			elseif player and player:IsA("Player") then
				Spectate.player = player
				notify("Spectating " .. player.Name .. ".")
			else
				notify("Pick a player first.")
			end
		end)

		playerSection:AddButton("Fling Player", function()
			local player = selectedPlayer and playersService:FindFirstChild(selectedPlayer)

			if not player or not player:IsA("Player") then
				notify("Pick a player first.")
				return
			end

			task.spawn(flingTargets, { player }, "Fling " .. player.Name)
		end)

		playerSection:AddButton("Fling All", function()
			local list = {}

			for _, player in next, playersService:GetPlayers() do
				if player ~= localPlayer and not PlayerLists.ignored[player.Name] and Targeting.getCharacter(player) then
					table.insert(list, player)
				end
			end

			task.spawn(flingTargets, list, "Fling all")
		end)

		playerSection:AddButton("Stop Fling", function()
			flingCancel = true
		end)

		local listSection = playersTab:AddSection("Lists", 2)

		local ignoreDropdown = listSection:AddDropdown("Ignore Players", getPlayerNames(), {}, function(value)
			setListFromDropdown(PlayerLists.ignored, value)
		end, { multi = true })

		local targetDropdown = listSection:AddDropdown("Priority Players", getPlayerNames(), {}, function(value)
			setListFromDropdown(PlayerLists.targeted, value)
		end, { multi = true })

		local teamDropdown = listSection:AddDropdown("Priority Teams", getTeamNames(), {}, function(value)
			setListFromDropdown(TeamTargets, value)
		end, { multi = true })

		listSection:AddLabel("Ignored players are skipped by aiming, ESP and Fling All. Priority targets are aimed at first.", { wrap = true })

		local function refreshPlayerLists()
			local names = getPlayerNames()

			playerDropdown:SetValues(names)
			ignoreDropdown:SetValues(names)
			targetDropdown:SetValues(names)
		end

		maid:add(playersService.PlayerAdded:Connect(function()
			task.delay(0.3, refreshPlayerLists)
		end))

		maid:add(playersService.PlayerRemoving:Connect(function()
			task.delay(0.3, refreshPlayerLists)
		end))

		local function refreshTeams()
			teamDropdown:SetValues(getTeamNames())
		end

		maid:add(teamsService.ChildAdded:Connect(refreshTeams))
		maid:add(teamsService.ChildRemoved:Connect(refreshTeams))
	end)

	safe("Misc tab", function()
		local movementSection = miscTab:AddSection("Movement", 1)
		addToggle(movementSection, "noclip", "Noclip")
		addToggle(movementSection, "fly", "Fly")
		addSlider(movementSection, "flySpeed", "Fly Speed", 20, 200, 0, " st/s")
		addToggle(movementSection, "infiniteJump", "Infinite Jump")
		addToggle(movementSection, "walkSpeedEnabled", "Custom WalkSpeed")
		addSlider(movementSection, "walkSpeedValue", "WalkSpeed", 16, 100, 0)
		movementSection:AddLabel("Fly moves using your normal movement input (joystick, WASD or gamepad) and your jump button to go up.", { wrap = true })

		local flingSection = miscTab:AddSection("Fling", 1)
		addSlider(flingSection, "flingRadius", "Orbit Radius", 1, 8, 1, " st")
		addSlider(flingSection, "flingSpeed", "Orbit Speed", 4, 40, 0)
		addToggle(flingSection, "flingReturn", "Return After Fling")

		local serverSection = miscTab:AddSection("Server", 2)

		serverSection:AddButton("Rejoin Server", function()
			if not pcall(teleportService.TeleportToPlaceInstance, teleportService, game.PlaceId, game.JobId, localPlayer) then
				teleportService:Teleport(game.PlaceId, localPlayer)
			end
		end)
	end)

	safe("Menu tab", function()
		local menuSection = menuTab:AddSection("Menu", 1)

		menuSection:AddKeybind("Menu Keybind", Enum.KeyCode.RightShift, function(key)
			ui.setMenuKey(key)
		end)

		menuSection:AddToggle("Lock Menu Button", false, function(value)
			ui.setMenuLocked(value)
		end)

		menuSection:AddButton("Reset Button Position", function()
			ui.menuButton.Position = ui.menuHome
		end)

		menuSection:AddButton("Hide Menu", function()
			ui.setMenuVisible(false)
		end)

		local actionSection = menuTab:AddSection("Actions", 1)

		actionSection:AddButton("Unload", function()
			cleanup()
		end)

		local configSection = menuTab:AddSection("Configs", 2)

		configNameInput = configSection:AddInput("Name", "", function(value)
			selectedConfigName = value
		end, "config name")

		configSection:AddButton("Save", saveConfig)
		configSection:AddButton("Load", loadConfig)
		configSection:AddButton("Delete", deleteConfig)

		configSection:AddButton("Set Auto-load", function()
			if not filesSupported or selectedConfigName == "" then
				notify("Type or pick a config name first.")
				return
			end

			pcall(writefile, autoloadPath, selectedConfigName)
			notify("\"" .. selectedConfigName .. "\" will load automatically next time.")
		end)

		configSection:AddButton("Remove Auto-load", function()
			if not filesSupported then
				return
			end

			pcall(function()
				if isfile(autoloadPath) then
					delfile(autoloadPath)
				end
			end)

			notify("Auto-load removed.")
		end)

		configListDropdown = configSection:AddDropdown("Saved Configs", listConfigNames(), nil, function(value)
			if value then
				selectedConfigName = value
				configNameInput:Set(value, true)
			end
		end)

		if not filesSupported then
			configSection:AddLabel("Your executor has no file API, so configs are unavailable here.", { wrap = true })
		else
			configSection:AddLabel("Configs are saved per game.", { wrap = true })
		end

		local utilitySection = menuTab:AddSection("Utility", 2)
		addToggle(utilitySection, "showWatermark", "Show Watermark")

		addToggle(utilitySection, "antiAfk", "Anti-AFK", function(value)
			setAntiAfk(value)
		end)

		addToggle(utilitySection, "performanceMode", "Performance Mode")
		addToggle(utilitySection, "performanceAuto", "Auto Performance Mode")
		addSlider(utilitySection, "performanceThreshold", "Auto Threshold", 10, 60, 0, " fps")
		utilitySection:AddLabel("Performance Mode hides skeleton and tracer ESP lines to save frames. Auto turns it on by itself when your FPS drops below the threshold. Anti-AFK stops the game from kicking you for being idle.", { wrap = true })

		local overviewSection = menuTab:AddSection("Keybind Overview", 2)

		if #ui.keybindRegistry == 0 then
			overviewSection:AddLabel("No keybinds registered yet.", { wrap = true })
		else
			for _, entry in next, ui.keybindRegistry do
				entry.display = overviewSection:AddLabel(entry.label .. ":  " .. entry.bind.Describe(entry.bind.Key))
			end
		end
	end)

	selectTab(ui.tabs[1])
	ui.setMenuVisible(true)

	safe("ESP", function()
		if not drawingSupported then
			notify("Your executor has no Drawing library, so ESP and the FOV circle are unavailable.")
			return
		end

		for _, player in next, playersService:GetPlayers() do
			addPlayer(player)
		end

		maid:add(playersService.PlayerAdded:Connect(addPlayer))
		maid:add(playersService.PlayerRemoving:Connect(removePlayer))
	end)

	safe("Frame loops", function()
		for _, name in next, RENDER_BINDS do
			pcall(runService.UnbindFromRenderStep, runService, name)
		end

		local base = Enum.RenderPriority.Camera.Value

		local function frame()
			Hitbox.update()
			Targeting.update()
		end

		runService:BindToRenderStep(RENDER_BINDS[1], base + 1, protect("Targeting", frame))
		runService:BindToRenderStep(RENDER_BINDS[2], base + 2, protect("Camlock", updateCamlock))
		runService:BindToRenderStep(RENDER_BINDS[3], base + 3, protect("Triggerbot", updateTrigger))
		runService:BindToRenderStep(RENDER_BINDS[4], base + 4, protect("ESP", Esp.updateAll))
		runService:BindToRenderStep(RENDER_BINDS[5], base - 1, protect("Spectate", Spectate.update))
	end)

	safe("Auto-load config", function()
		if not filesSupported then
			return
		end

		local success, name = pcall(readfile, autoloadPath)

		if success and name and name ~= "" then
			selectedConfigName = name
			configNameInput:Set(name, true)
			loadConfig()
		end
	end)

	notify("Loaded universal. RightShift or the M button opens the menu.")
end

local GAMES = {
	{ id = "mm2", name = "Murder Mystery 2", places = { [142823291] = true }, universes = { [66654135] = true } },
	{ id = "universal", name = "Universal", tag = "any game" },
}

local RUNNERS = {
	mm2 = runMM2,
	universal = runUniversal,
}

local function detectGame()
	for _, entry in next, GAMES do
		if (entry.places and entry.places[game.PlaceId]) or (entry.universes and entry.universes[game.GameId]) then
			return entry.id, true
		end
	end

	return "universal", false
end

local function showLauncher(detected, matched, onSelect)
	local guiParent = gethui and gethui() or game:GetService("CoreGui")
	local viewport = workspaceService.CurrentCamera and workspaceService.CurrentCamera.ViewportSize or Vector2.new(800, 400)
	local panelWidth = math.min(300, viewport.X - 30)
	local cardWidth = math.floor((panelWidth - 28 - 8 * (#GAMES - 1)) / #GAMES)
	local panelHeight = 232
	local closing = false

	local launcherGui = make("ScreenGui", {
		Name = "MagmaLauncher",
		ResetOnSpawn = false,
		DisplayOrder = 1000001,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = guiParent,
	})

	shared.MagmaLauncher = launcherGui

	local dim = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = launcherGui,
	})

	tweenService:Create(dim, TweenInfo.new(0.4), { BackgroundTransparency = 0.4 }):Play()

	local panel = make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(panelWidth, panelHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = launcherGui,
	})

	round(panel, 18)
	addStroke(panel, THEME.accentDark)

	local panelBackground = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Parent = panel,
	})

	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(30, 15, 20), Color3.fromRGB(11, 11, 13)),
		Rotation = 90,
		Parent = panelBackground,
	})

	local panelScale = make("UIScale", { Scale = 0.9, Parent = panel })

	tweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
	tweenService:Create(panelScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local shimmer = make("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = THEME.accent,
		BorderSizePixel = 0,
		Parent = panel,
	})

	local shimmerGradient = make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = shimmer,
	})

	tweenService:Create(shimmerGradient, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(1, 0) }):Play()

	textLabel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, -28, 0, 30),
		Text = '<font color="rgb(235,235,238)">mag</font><font color="rgb(200,48,68)">ma</font>',
		RichText = true,
		Font = FONT_BOLD,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})

	textLabel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.new(1, -28, 0, 14),
		Text = "select your game",
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = panel,
	})

	local function choose(id)
		if closing then
			return
		end

		closing = true

		tweenService:Create(panel, TweenInfo.new(0.22), { GroupTransparency = 1 }):Play()
		tweenService:Create(panelScale, TweenInfo.new(0.22), { Scale = 0.94 }):Play()
		tweenService:Create(dim, TweenInfo.new(0.22), { BackgroundTransparency = 1 }):Play()

		task.delay(0.25, function()
			launcherGui:Destroy()

			if shared.MagmaLauncher == launcherGui then
				shared.MagmaLauncher = nil
			end

			onSelect(id)
		end)
	end

	for index, entry in next, GAMES do
		local isDetected = entry.id == detected
		local x = 14 + (index - 1) * (cardWidth + 8)

		if isDetected then
			local glow = make("Frame", {
				Position = UDim2.fromOffset(x - 5, 71),
				Size = UDim2.fromOffset(cardWidth + 10, 150),
				BackgroundColor3 = THEME.accent,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				Parent = panel,
			})

			round(glow, 16)

			tweenService:Create(glow, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.94 }):Play()
		end

		local card = make("TextButton", {
			Position = UDim2.fromOffset(x, 76),
			Size = UDim2.fromOffset(cardWidth, 142),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			Parent = panel,
		})

		round(card, 13)

		local stroke = addStroke(card, isDetected and THEME.accent or THEME.line)
		stroke.Thickness = isDetected and 1.5 or 1

		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(38, 38, 45), Color3.fromRGB(20, 20, 24)),
			Rotation = 90,
			Parent = card,
		})

		local cardScale = make("UIScale", { Scale = 1, Parent = card })

		local iconFrame = makeGameIcon(card, entry.id, UDim2.fromOffset(58, 58), UDim2.new(0.5, -29, 0, 12), 14)
		addStroke(iconFrame, isDetected and THEME.accent or THEME.accentDark)

		textLabel({
			Position = UDim2.fromOffset(6, 74),
			Size = UDim2.new(1, -12, 0, 28),
			Text = entry.name,
			TextColor3 = THEME.textBright,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})

		local badgeText = entry.tag and string.upper(entry.tag) or ""

		if isDetected then
			badgeText = matched and "DETECTED" or "RECOMMENDED"
		end

		if badgeText ~= "" then
			local badge = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 108),
				Size = UDim2.new(1, -20, 0, 20),
				BackgroundColor3 = isDetected and THEME.accent or THEME.line,
				BackgroundTransparency = isDetected and 0.75 or 0.4,
				BorderSizePixel = 0,
				Parent = card,
			})

			round(badge, 10)

			textLabel({
				Size = UDim2.fromScale(1, 1),
				Text = badgeText,
				TextColor3 = isDetected and THEME.accent or THEME.text,
				Font = FONT_BOLD,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = badge,
			})
		end

		card.MouseEnter:Connect(function()
			tweenService:Create(stroke, TweenInfo.new(0.15), { Color = THEME.accent }):Play()
		end)

		card.MouseLeave:Connect(function()
			tweenService:Create(stroke, TweenInfo.new(0.15), { Color = isDetected and THEME.accent or THEME.line }):Play()
		end)

		card.InputBegan:Connect(function(input)
			if isPress(input) then
				tweenService:Create(cardScale, TweenInfo.new(0.1), { Scale = 0.95 }):Play()
			end
		end)

		card.InputEnded:Connect(function(input)
			if isPress(input) then
				tweenService:Create(cardScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
			end
		end)

		card.Activated:Connect(function()
			choose(entry.id)
		end)
	end
end

if shared.Magma then
	pcall(shared.Magma.unload)
end

if shared.MagmaLauncher then
	pcall(function()
		shared.MagmaLauncher:Destroy()
	end)

	shared.MagmaLauncher = nil
end

for _, key in next, { "MM2Hub", "MM2Script", "MM2Gui" } do
	if shared[key] then
		pcall(shared[key].unload)
	end
end

local detectedId, matched = detectGame()

showLauncher(detectedId, matched, function(choice)
	local runner = RUNNERS[choice]

	xpcall(runner, function(message)
		warn(debug.traceback(tostring(message)))
		notify("Startup error: " .. tostring(message))
	end)
end)
