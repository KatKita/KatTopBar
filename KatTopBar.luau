--[[

Does not work correctly in clients that lack a TopBar

]]

local KatTopBar = {}

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

KatTopBar.Initialized = false
KatTopBar.Version = 1
KatTopBar.TopbarTransparency = 0.5
KatTopBar.Gui = nil
KatTopBar.Buttons = {}

-- TODO
--[[
* Add text buttons like TopBarPlus
* Add DropDown like TopBarPlus
* Fix left offset if the player has the topbar offset enabled, not possible for now dont even try
]]

local transparencyChangedEvent = Instance.new("BindableEvent")

KatTopBar.TransparencyChanged = transparencyChangedEvent.Event

local buttonCounter = 0
local lastCoreAttempt = 0
local mouseConnections = {}
local pressedButton = nil

local rightOffset = 170 -- padding from username and this health bar
local defaultButtonSize = UDim2.new(0, 50, 0, 36)
local defaultIconSize = UDim2.new(0, 22, 0, 28)

local function Create(className, properties, parent)
	local object = Instance.new(className)

	for property, value in pairs(properties) do
		object[property] = value
	end

	object.Parent = parent

	return object
end

local function HideOriginalTopBar()
	pcall(function()
		PlayerGui:SetTopbarTransparency(1)
	end)
end

local function GetFirstButtonPosition()
	local position = 50

	local chatSuccess, chatEnabled = pcall(function()
		return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat) -- This all StarterGui:GetCoreGuiEnabled(?) may not work in some clients
	end)

	if chatSuccess and chatEnabled then
		position = position + 50
	end

	local backpackSuccess, backpackEnabled = pcall(function()
		return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)

	if backpackSuccess and backpackEnabled then
		position = position + 50
	end

	return position
end

local function GetTopBar()
	if not KatTopBar.Gui then
		return nil
	end

	return KatTopBar.Gui:FindFirstChild("TopBar")
end

local function GetButtonWidth(button, topbar)
	if button.ImageButton then
		local width = button.ImageButton.AbsoluteSize.X

		if width > 0 then
			return width
		end
	end

	return button.Size.X.Scale * topbar.AbsoluteSize.X + button.Size.X.Offset
end

local function SortButtons(buttons)
	table.sort(buttons, function(a, b)
		if a.Order == b.Order then
			return a.ID < b.ID
		end

		return a.Order < b.Order
	end)
end

local function UpdateButtonIcon(button)
	local icon = button.IconLabel

	if not icon then
		return
	end

	local iconSize = button.IconSize or defaultIconSize

	icon.Size = iconSize
	icon.Position = button.IconPosition or UDim2.new(
		0.5 - iconSize.X.Scale / 2,
		-iconSize.X.Offset / 2,
		0.5 - iconSize.Y.Scale / 2,
		-iconSize.Y.Offset / 2
	) -- so dont use the anchor point here, as its not available in all clients

	icon.Image = button.Active and (button.ActiveIcon or button.Icon) or button.Icon
	icon.ImageColor3 = button.IconColor
end

local function UpdateCounter(button)
	local counter = button.Counter

	if not counter then
		return
	end

	local value = button.CounterValue
	local text = value ~= nil and tostring(value) or ""

	counter.Visible = text ~= "" and text ~= "0"
	button.CounterText.Text = text
end

local function CreateCounter(button)
	if button.Counter then
		button.Counter:Destroy()
	end

	if not button.IconLabel then
		return
	end

	local counter = Create("ImageLabel", {
		Name = "Counter",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 18, 0, 18),
		Position = UDim2.new(1, -12, 0, -4),
		Image = "rbxasset://textures/ui/Chat/MessageCounter.png", 
		Visible = false
	}, button.IconLabel)

	local counterText = Create("TextLabel", {
		Name = "CounterText",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -7, 0.5, -7),
		Size = UDim2.new(0, 13, 0, 9),
		Font = Enum.Font.SourceSansBold,
		FontSize = Enum.FontSize.Size10,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		TextWrapped = true
	}, counter)

	button.Counter = counter
	button.CounterText = counterText

	UpdateCounter(button)
end

local function UpdateButtonPositions()
	local topbar = GetTopBar()

	if not topbar then
		return
	end

	local groups = {
		left = {},
		center = {},
		right = {}
	}

	for _, button in ipairs(KatTopBar.Buttons) do
		if not button.Destroyed and button.Visible then
			local group = groups[button.Type] or groups.left

			table.insert(group, button)
		end
	end

	for _, buttons in pairs(groups) do
		SortButtons(buttons)
	end

	local leftPosition = GetFirstButtonPosition()

	for _, button in ipairs(groups.left) do
		if button.ImageButton and button.ImageButton.Parent == topbar then
			button.ImageButton.Position = UDim2.new(0, leftPosition, 0, 0)
		end

		leftPosition = leftPosition + GetButtonWidth(button, topbar)
	end

	local centerWidth = 0

	for _, button in ipairs(groups.center) do
		centerWidth = centerWidth + GetButtonWidth(button, topbar)
	end

	local centerPosition = -centerWidth / 2

	for _, button in ipairs(groups.center) do
		if button.ImageButton and button.ImageButton.Parent == topbar then
			button.ImageButton.Position = UDim2.new(0.5, centerPosition, 0, 0)
		end

		centerPosition = centerPosition + GetButtonWidth(button, topbar)
	end

	local rightWidth = 0

	for _, button in ipairs(groups.right) do
		rightWidth = rightWidth + GetButtonWidth(button, topbar)
	end

	local rightPosition = -rightOffset - rightWidth

	for _, button in ipairs(groups.right) do
		if button.ImageButton and button.ImageButton.Parent == topbar then
			button.ImageButton.Position = UDim2.new(1, rightPosition, 0, 0)
		end

		rightPosition = rightPosition + GetButtonWidth(button, topbar)
	end
end

local function IsCursorOverButton(button, cursorPosition)
	if not button or button.Destroyed or not button.Visible then
		return false
	end

	local imageButton = button.ImageButton
	local topbar = GetTopBar()

	if not imageButton or not topbar then
		return false
	end

	if imageButton.Parent ~= topbar or not imageButton.Visible or not topbar.Visible then
		return false
	end

	local position = imageButton.AbsolutePosition
	local size = imageButton.AbsoluteSize

	return cursorPosition.X >= position.X
		and cursorPosition.X < position.X + size.X
		and cursorPosition.Y >= position.Y
		and cursorPosition.Y < position.Y + size.Y
end

local function GetButtonAtCursor(cursorPosition)
	local sortedButtons = {}

	for _, button in ipairs(KatTopBar.Buttons) do
		if not button.Destroyed then
			table.insert(sortedButtons, button)
		end
	end

	SortButtons(sortedButtons)

	for index = #sortedButtons, 1, -1 do
		local button = sortedButtons[index]

		if IsCursorOverButton(button, cursorPosition) then
			return button
		end
	end

	return nil
end

local function DisconnectMouseInput()
	for _, connection in ipairs(mouseConnections) do
		connection:Disconnect()
	end

	mouseConnections = {}
	pressedButton = nil
end

local function ConnectMouseInput()
	if #mouseConnections > 0 then
		return
	end

	table.insert(mouseConnections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		if pressedButton then
			if not pressedButton.Destroyed and pressedButton.Mode == "Momentary" then
				pressedButton:SetActive(false)
			end

			pressedButton = nil
		end

		local button = GetButtonAtCursor(input.Position)

		if not button then
			return
		end

		pressedButton = button

		if button.Mode == "Toggle" then
			button:SetActive(not button.Active)
		elseif button.Mode == "Momentary" then
			button:SetActive(true)
		end

		button.ClickedEvent:Fire(button.Active, button)
	end))

	table.insert(mouseConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local button = pressedButton
		pressedButton = nil

		if button and not button.Destroyed and button.Mode == "Momentary" then
			button:SetActive(false)
		end
	end))
end

local function CreateButtonGui(button)
	local topbar = GetTopBar()

	if not topbar then
		return false
	end

	if button.ImageButton then
		button.ImageButton:Destroy()
	end

	button.ImageButton = nil
	button.IconLabel = nil
	button.Counter = nil
	button.CounterText = nil

	local imageButton = Create("ImageButton", {
		Name = button.Name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = button.Size,
		Position = UDim2.new(0, 0, 0, 0),
		Image = "",
		Visible = button.Visible
	}, topbar)

	button.ImageButton = imageButton

	local icon = Create("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = button.IconSize or defaultIconSize,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Image = "",
		Visible = true
	}, imageButton)

	button.IconLabel = icon

	UpdateButtonIcon(button)

	if button.CounterEnabled then
		CreateCounter(button)
	end

	return true
end

local function RestoreButton(button)
	if button.Destroyed then
		return false
	end

	local topbar = GetTopBar()

	if not topbar then
		return false
	end

	if not button.ImageButton
		or button.ImageButton.Parent ~= topbar
		or not button.IconLabel
		or button.IconLabel.Parent ~= button.ImageButton then

		return CreateButtonGui(button)
	end

	if button.CounterEnabled and (
		not button.Counter
		or button.Counter.Parent ~= button.IconLabel
	) then
		CreateCounter(button)
	end

	return true
end

function KatTopBar:MakeTopBar()
	if not PlayerGui or not PlayerGui.Parent then
		PlayerGui = Player:WaitForChild("PlayerGui")
	end

	if not KatTopBar.Gui
		or not KatTopBar.Gui.Parent
		or KatTopBar.Gui.Parent ~= PlayerGui then

		KatTopBar.Gui = Create("ScreenGui", {
			Name = "KatTopBar"
		}, PlayerGui)
	end

	local topbar = GetTopBar()

	if not topbar then
		topbar = Create("Frame", {
			Name = "TopBar",
			BackgroundColor3 = Color3.fromRGB(31, 31, 31),
			BackgroundTransparency = KatTopBar.TopbarTransparency,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, -36),
			Size = UDim2.new(1, 0, 0, 36)
		}, KatTopBar.Gui)
	end

	for _, button in ipairs(KatTopBar.Buttons) do
		RestoreButton(button)
	end

	UpdateButtonPositions()

	return topbar
end

function KatTopBar:SetTopbarTransparency(transparency)
	if type(transparency) ~= "number" then
		return false, "Transparency must be a number"
	end

	if transparency < 0 or transparency > 1 then
		return false, "Transparency must be between 0 and 1"
	end

	if KatTopBar.TopbarTransparency == transparency then
		return true
	end

	KatTopBar.TopbarTransparency = transparency

	local topbar = GetTopBar()

	if topbar then
		topbar.BackgroundTransparency = transparency
	end

	transparencyChangedEvent:Fire(transparency)

	return true
end

function KatTopBar:GetTopbarTransparency()
	return KatTopBar.TopbarTransparency
end

function KatTopBar:AddButton(config)
	if type(config) ~= "table" then
		return nil, "Configuration must be a table"
	end

	local buttonType = config.Type or "left"

	if buttonType ~= "left" and buttonType ~= "center" and buttonType ~= "right" then
		return nil, "Type must be left, center or right"
	end

	local mode = config.Mode or "Toggle"

	if mode ~= "Toggle" and mode ~= "Momentary" then
		return nil, "Mode must be Toggle or Momentary"
	end

	local iconPosition = config.IconPosition or config.Position

	if iconPosition ~= nil and typeof(iconPosition) ~= "UDim2" then
		return nil, "IconPosition must be UDim2"
	end

	buttonCounter = buttonCounter + 1

	local button = {}

	button.ID = buttonCounter
	button.Name = config.Name or tostring(buttonCounter)

	button.Icon = config.Icon or ""
	button.ActiveIcon = config.ActiveIcon

	button.Size = config.Size or defaultButtonSize
	button.IconSize = config.IconSize or defaultIconSize
	button.IconPosition = iconPosition

	button.Order = config.Order or (#KatTopBar.Buttons + 1)
	button.Type = buttonType
	button.Mode = mode
	button.Active = config.Active == true
	button.Visible = config.Visible ~= false

	button.IconColor = config.IconColor or Color3.new(1, 1, 1)

	button.CounterEnabled = config.Counter == true
	button.CounterValue = config.CounterValue

	button.Destroyed = false

	button.ImageButton = nil
	button.IconLabel = nil
	button.Counter = nil
	button.CounterText = nil

	button.ClickedEvent = Instance.new("BindableEvent")
	button.StateChangedEvent = Instance.new("BindableEvent")

	button.Clicked = button.ClickedEvent.Event
	button.StateChanged = button.StateChangedEvent.Event

	function button:SetActive(active)
		if self.Destroyed then
			return false
		end

		if type(active) ~= "boolean" then
			return false, "Active must be a boolean"
		end

		if self.Active == active then
			return true
		end

		self.Active = active

		UpdateButtonIcon(self)
		self.StateChangedEvent:Fire(active, self)

		return true
	end

	function button:SetSize(size)
		if typeof(size) ~= "UDim2" then
			return false, "Size must be UDim2"
		end

		self.Size = size

		if self.ImageButton then
			self.ImageButton.Size = size
		end

		UpdateButtonPositions()

		return true
	end

	function button:SetIcon(image)
		if type(image) ~= "string" then
			return false, "Image must be a string"
		end

		self.Icon = image

		UpdateButtonIcon(self)

		return true
	end

	function button:SetActiveIcon(image)
		if type(image) ~= "string" then
			return false, "Image must be a string"
		end

		self.ActiveIcon = image

		UpdateButtonIcon(self)

		return true
	end

	function button:SetIconSize(size)
		if typeof(size) ~= "UDim2" then
			return false, "Size must be UDim2"
		end

		self.IconSize = size

		UpdateButtonIcon(self)

		return true
	end

	function button:SetIconPosition(position)
		if position ~= nil and typeof(position) ~= "UDim2" then
			return false, "Position must be UDim2 or nil"
		end

		self.IconPosition = position

		UpdateButtonIcon(self)

		return true
	end

	function button:SetCounter(value)
		if not self.CounterEnabled then
			return false, "Counter is disabled"
		end

		self.CounterValue = value

		UpdateCounter(self)

		return true
	end

	function button:EnableCounter(value)
		self.CounterEnabled = true
		self.CounterValue = value

		if self.IconLabel then
			CreateCounter(self)
		end

		return true
	end

	function button:SetOrder(order)
		if type(order) ~= "number" or order < 1 then
			return false, "Order must be a positive number"
		end

		self.Order = math.floor(order)

		UpdateButtonPositions()

		return true
	end

	function button:SetType(buttonType)
		if buttonType ~= "left" and buttonType ~= "center" and buttonType ~= "right" then
			return false, "Type must be left, center or right"
		end

		self.Type = buttonType

		UpdateButtonPositions()

		return true
	end

	function button:SetMode(mode)
		if mode ~= "Toggle" and mode ~= "Momentary" then
			return false, "Unknown button mode"
		end

		self.Mode = mode

		if mode == "Momentary" then
			self:SetActive(false)
		end

		return true
	end

	function button:SetVisible(visible)
		if type(visible) ~= "boolean" then
			return false, "Visible must be a boolean"
		end

		self.Visible = visible

		if self.ImageButton then
			self.ImageButton.Visible = visible
		end

		UpdateButtonPositions()

		return true
	end

	function button:SetIconColor(color)
		if typeof(color) ~= "Color3" then
			return false, "Color must be Color3"
		end

		self.IconColor = color

		if self.IconLabel then
			self.IconLabel.ImageColor3 = color
		end

		return true
	end

	function button:Destroy()
		if self.Destroyed then
			return
		end

		if pressedButton == self then
			pressedButton = nil
		end

		self.Destroyed = true

		if self.ImageButton then
			self.ImageButton:Destroy()
			self.ImageButton = nil
		end

		for index, existingButton in ipairs(KatTopBar.Buttons) do
			if existingButton == self then
				table.remove(KatTopBar.Buttons, index)
				break
			end
		end

		self.ClickedEvent:Destroy()
		self.StateChangedEvent:Destroy()

		UpdateButtonPositions()
	end

	table.insert(KatTopBar.Buttons, button)

	CreateButtonGui(button)
	UpdateButtonPositions()

	return button
end

function KatTopBar:Init()
	if KatTopBar.Initialized then
    -- warn("KatTopBar is already initialized")
		return false, "Already initialized"
	end

	KatTopBar.Initialized = true

	KatTopBar:MakeTopBar()
	ConnectMouseInput()
	HideOriginalTopBar()

	spawn(function()
		while KatTopBar.Initialized do
			wait(0.25) -- if it lags change the increment to a larger number like for example 0.5

			if not KatTopBar.Initialized then
				break
			end

			if not PlayerGui or not PlayerGui.Parent then
				PlayerGui = Player:WaitForChild("PlayerGui")
			end

			if not KatTopBar.Gui or not KatTopBar.Gui.Parent then
				KatTopBar.Gui = nil
				KatTopBar:MakeTopBar()
			end

			local topbar = GetTopBar()

			if not topbar then
				KatTopBar:MakeTopBar()
			else
				if topbar.BackgroundTransparency ~= KatTopBar.TopbarTransparency then
					topbar.BackgroundTransparency = KatTopBar.TopbarTransparency
				end

				local expectedPosition = UDim2.new(0, 0, 0, -36)

				if topbar.Position ~= expectedPosition then
					topbar.Position = expectedPosition
				end
			end

			for _, button in ipairs(KatTopBar.Buttons) do
				RestoreButton(button)
			end

			UpdateButtonPositions()

			if tick() - lastCoreAttempt >= 1 then
				lastCoreAttempt = tick()
				HideOriginalTopBar()
			end
		end
	end)

	return true
end

function KatTopBar:Destroy() 
	if not KatTopBar.Initialized then
		return false
	end

	KatTopBar.Initialized = false

	DisconnectMouseInput()

	while #KatTopBar.Buttons > 0 do
		KatTopBar.Buttons[1]:Destroy()
	end

	if KatTopBar.Gui then
		KatTopBar.Gui:Destroy()
		KatTopBar.Gui = nil
	end

	return true
end

return KatTopBar
