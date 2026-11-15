--[[

Does not work correctly in clients that lack a TopBar

]]

local KatTopBar = {}

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

if not RunService:IsClient() then
	warn("KatTopBar must be required from a LocalScript")
	return false
end

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

KatTopBar.Initialized = false
KatTopBar.Version = 1.02
KatTopBar.TopbarTransparency = 0.5
KatTopBar.TopBarColor = Color3.fromRGB(31, 31, 31)
KatTopBar.Gui = nil

KatTopBar.Buttons = {}
KatTopBar.LeaderstatsColumns = {}
KatTopBar.Texts = {}
KatTopBar.Elements = {}

--[[
  TODO

* Add DropDown like TopBarPlus
* Fix left offset if the player has the topbar offset enabled, not possible for now dont even try
]]

local transparencyChangedEvent = Instance.new("BindableEvent")
KatTopBar.TransparencyChanged = transparencyChangedEvent.Event

local colorChangedEvent = Instance.new("BindableEvent")
KatTopBar.ColorChanged = colorChangedEvent

local elementCounter = 0
local lastCoreAttempt = 0
local mouseConnections = {}
local pressedElement = nil

local rightOffset = 170
local defaultButtonSize = UDim2.new(0, 50, 0, 36)
local defaultIconSize = UDim2.new(0, 22, 0, 28)
local defaultColumnWidth = 77
local defaultTextSize = Enum.FontSize.Size14

local transparencyChangedng = false

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

PlayerGui.TopbarTransparencyChangedSignal:Connect(function(newTransparency)
	if not transparencyChangedng and newTransparency ~= 1 and KatTopBar.Initialized then
		KatTopBar:SetTopbarTransparency(newTransparency)

		transparencyChangedng = true
		HideOriginalTopBar()
		transparencyChangedng = false
	end
end)

local function GetFirstButtonPosition()
	local position = 50

	local chatSuccess, chatEnabled = pcall(function()
		return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat)
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

local function SortElements(elements)
	table.sort(elements, function(a, b)
		if a.Order == b.Order then
			return a.ID < b.ID
		end

		return a.Order < b.Order
	end)
end

KatTopBar.SortElements = SortElements

local function RegisterElement(element)
	table.insert(KatTopBar.Elements, element)
end

local function UnregisterElement(element)
	for index, existingElement in ipairs(KatTopBar.Elements) do
		if existingElement == element then
			table.remove(KatTopBar.Elements, index)
			break
		end
	end
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

local function GetElementWidth(element, topbar)
	if element.Kind == "Button" then
		return GetButtonWidth(element, topbar)
	end

	local guiObject = element.GuiObject

	if guiObject then
		local width = guiObject.AbsoluteSize.X

		if width > 0 then
			return width
		end
	end

	local size = element.Size

	if size then
		return size.X.Scale * topbar.AbsoluteSize.X + size.X.Offset
	end

	return 0
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
	)

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

local function GetVisibleColumnCount()
	local camera = workspace.CurrentCamera

	if not camera then
		return 0
	end

	local viewportSize = camera.ViewportSize
	local screenWidth = viewportSize.X
	local screenHeight = viewportSize.Y

	if screenWidth < screenHeight then
		return 0
	end

	if screenWidth < 700 or screenHeight < 500 then
		return 1
	end

	return #KatTopBar.LeaderstatsColumns
end

local function GetVisibleLeaderstatsColumns()
	local columns = {}

	for _, column in ipairs(KatTopBar.LeaderstatsColumns) do
		if not column.Destroyed and column.Visible then
			table.insert(columns, column)
		end
	end

	SortElements(columns)

	local maxColumns = GetVisibleColumnCount()

	while #columns > maxColumns do
		table.remove(columns)
	end

	return columns
end

local function GetLeaderstatsWidth()
	local leaderstats = Player:FindFirstChild("leaderstats")

	if not leaderstats then
		return 0
	end

	local camera = workspace.CurrentCamera

	if not camera then
		return 0
	end

	local viewportSize = camera.ViewportSize
	local screenWidth = viewportSize.X
	local screenHeight = viewportSize.Y

	if screenWidth < screenHeight then
		return 0
	end

	local maxColumns = 4

	if screenWidth < 700 or screenHeight < 500 then
		maxColumns = 1
	end

	local uniqueNames = {}
	local columnCount = 0

	for _, stat in ipairs(leaderstats:GetChildren()) do
		if not uniqueNames[stat.Name] then
			uniqueNames[stat.Name] = true
			columnCount = columnCount + 1

			if columnCount >= maxColumns then
				break
			end
		end
	end

	return columnCount * defaultColumnWidth
end

local function UpdateColumnVisibility()
	local visibleColumns = GetVisibleLeaderstatsColumns()
	local visibleLookup = {}

	for _, column in ipairs(visibleColumns) do
		visibleLookup[column] = true
	end

	for _, column in ipairs(KatTopBar.LeaderstatsColumns) do
		local visible = visibleLookup[column] == true

		if column.LeaderstatsContainer then
			column.LeaderstatsContainer.Visible = visible
		end
	end
end

local function CreateColumnGui(column)
	local topbar = GetTopBar()

	if not topbar then
		return false
	end

	if column.LeaderstatsContainer then
		column.LeaderstatsContainer:Destroy()
	end

	column.LeaderstatsContainer = nil
	column.Column = nil
	column.ColumnName = nil
	column.ColumnValue = nil

	local container = Create("Frame", {
		Name = "LeaderstatsContainer",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, defaultColumnWidth, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Visible = column.Visible
	}, topbar)

	local columnFrame = Create("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 75, 1, 0),
		Position = UDim2.new(0, 2, 0, 0)
	}, container)

	local columnName = Create("TextLabel", {
		Name = "ColumnName",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 0, 4),
		FontSize = Enum.FontSize.Size10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = column.NameColor,
		Text = column.Name
	}, columnFrame)

	local columnValue = Create("TextLabel", {
		Name = "ColumnValue",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 0, 19),
		FontSize = defaultTextSize,
		Font = Enum.Font.SourceSansBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = column.ValueColor,
		Text = column.Value
	}, columnFrame)

	column.LeaderstatsContainer = container
	column.Column = columnFrame
	column.ColumnName = columnName
	column.ColumnValue = columnValue

	return true
end

local function RestoreColumn(column)
	if column.Destroyed then
		return false
	end

	local topbar = GetTopBar()

	if not topbar then
		return false
	end

	if not column.LeaderstatsContainer
		or column.LeaderstatsContainer.Parent ~= topbar
		or not column.Column
		or column.Column.Parent ~= column.LeaderstatsContainer
		or not column.ColumnName
		or column.ColumnName.Parent ~= column.Column
		or not column.ColumnValue
		or column.ColumnValue.Parent ~= column.Column then

		return CreateColumnGui(column)
	end

	return true
end

local function GetElementGui(element)
	if element.Kind == "Button" then
		return element.ImageButton
	elseif element.Kind == "LeaderstatsColumn" then
		return element.LeaderstatsContainer
	end

	return element.GuiObject
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

	for _, element in ipairs(KatTopBar.Elements) do
		if element.Kind ~= "LeaderstatsColumn"
			and not element.Destroyed
			and element.Visible then

			local group = groups[element.Type] or groups.left
			table.insert(group, element)
		end
	end

	for _, elements in pairs(groups) do
		SortElements(elements)
	end

	UpdateColumnVisibility()

	local visibleColumns = GetVisibleLeaderstatsColumns()

	local customStatsWidth = #visibleColumns * defaultColumnWidth
	local coreGuiStatsWidth = GetLeaderstatsWidth()
	local statsWidth = customStatsWidth + coreGuiStatsWidth

	local statsStart = topbar.AbsoluteSize.X - rightOffset - statsWidth

	for index, column in ipairs(visibleColumns) do
		if column.LeaderstatsContainer
			and column.LeaderstatsContainer.Parent == topbar then

			column.LeaderstatsContainer.Position = UDim2.new(
				0,
				statsStart + (index - 1) * defaultColumnWidth,
				0,
				0
			)
		end
	end

	local leftPosition = GetFirstButtonPosition()

	for _, element in ipairs(groups.left) do
		local guiObject = GetElementGui(element)

		if guiObject and guiObject.Parent == topbar then
			guiObject.Position = UDim2.new(0, leftPosition, 0, 0)
		end

		leftPosition = leftPosition + GetElementWidth(element, topbar)
	end

	local centerWidth = 0

	for _, element in ipairs(groups.center) do
		centerWidth = centerWidth + GetElementWidth(element, topbar)
	end

	local rightWidth = 0

	for _, element in ipairs(groups.right) do
		rightWidth = rightWidth + GetElementWidth(element, topbar)
	end

	local rightBoundary = topbar.AbsoluteSize.X - rightOffset - statsWidth - rightWidth
	local availableWidth = rightBoundary - leftPosition
	local centerPosition = leftPosition + availableWidth / 2 - centerWidth / 2

	for _, element in ipairs(groups.center) do
		local guiObject = GetElementGui(element)

		if guiObject and guiObject.Parent == topbar then
			guiObject.Position = UDim2.new(0, centerPosition, 0, 0)
		end

		centerPosition = centerPosition + GetElementWidth(element, topbar)
	end

	local rightPosition = -(rightOffset + statsWidth) - rightWidth

	for _, element in ipairs(groups.right) do
		local guiObject = GetElementGui(element)

		if guiObject and guiObject.Parent == topbar then
			guiObject.Position = UDim2.new(1, rightPosition, 0, 0)
		end

		rightPosition = rightPosition + GetElementWidth(element, topbar)
	end
end

local function IsCursorOverElement(element, cursorPosition)
	if not element or element.Destroyed or not element.Visible then
		return false
	end

	local guiObject = GetElementGui(element)
	local topbar = GetTopBar()

	if not guiObject or not topbar then
		return false
	end

	if guiObject.Parent ~= topbar or not guiObject.Visible or not topbar.Visible then
		return false
	end

	local position = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize

	return cursorPosition.X >= position.X
		and cursorPosition.X < position.X + size.X
		and cursorPosition.Y >= position.Y
		and cursorPosition.Y < position.Y + size.Y
end

local function GetElementAtCursor(cursorPosition)
	local sortedElements = {}

	for _, element in ipairs(KatTopBar.Elements) do
		if not element.Destroyed then
			table.insert(sortedElements, element)
		end
	end

	SortElements(sortedElements)

	for index = #sortedElements, 1, -1 do
		local element = sortedElements[index]

		if IsCursorOverElement(element, cursorPosition) then
			return element
		end
	end

	return nil
end

local function DisconnectMouseInput()
	for _, connection in ipairs(mouseConnections) do
		connection:Disconnect()
	end

	mouseConnections = {}
	pressedElement = nil
end

local function ConnectMouseInput()
	if #mouseConnections > 0 then
		return
	end

	table.insert(mouseConnections, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		if pressedElement then
			if not pressedElement.Destroyed
				and pressedElement.Kind == "Button"
				and pressedElement.Mode == "Momentary" then

				pressedElement:SetActive(false)
			end

			pressedElement = nil
		end

		local element = GetElementAtCursor(input.Position)

		if not element then
			return
		end

		pressedElement = element

		if element.Kind == "Button" then
			if element.Mode == "Toggle" then
				element:SetActive(not element.Active)
			elseif element.Mode == "Momentary" then
				element:SetActive(true)
			end

			element.ClickedEvent:Fire(element.Active, element)

		elseif element.Kind == "LeaderstatsColumn" then
			element.ClickedEvent:Fire(element)

		elseif element.Kind == "Text" then
			element.ClickedEvent:Fire(element)
		end
	end))

	table.insert(mouseConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local element = pressedElement
		pressedElement = nil

		if element
			and not element.Destroyed
			and element.Kind == "Button"
			and element.Mode == "Momentary" then

			element:SetActive(false)
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

local function CreateTextGui(textElement)
	local topbar = GetTopBar()

	if not topbar then
		return false
	end

	if textElement.GuiObject then
		textElement.GuiObject:Destroy()
	end

	textElement.GuiObject = nil
	textElement.TextLabel = nil

	local textLabel = Create("TextLabel", {
		Name = textElement.Name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = textElement.Size,
		Position = UDim2.new(0, 0, 0, 0),
		Font = textElement.Font,
		FontSize = defaultTextSize,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = textElement.TextColor,
		Text = textElement.Text,
		TextWrapped = false,
		Visible = textElement.Visible
	}, topbar)

	textElement.GuiObject = textLabel
	textElement.TextLabel = textLabel

	return true
end

local function RestoreText(textElement)
	if textElement.Destroyed then
		return false
	end

	local topbar = GetTopBar()

	if not topbar then
		return false
	end

	if not textElement.GuiObject or textElement.GuiObject.Parent ~= topbar then
		return CreateTextGui(textElement)
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
			BackgroundColor3 = KatTopBar.TopBarColor,
			BackgroundTransparency = KatTopBar.TopbarTransparency,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, -36),
			Size = UDim2.new(1, 0, 0, 36)
		}, KatTopBar.Gui)
	end

	for _, button in ipairs(KatTopBar.Buttons) do
		RestoreButton(button)
	end

	for _, column in ipairs(KatTopBar.LeaderstatsColumns) do
		RestoreColumn(column)
	end

	for _, textElement in ipairs(KatTopBar.Texts) do
		RestoreText(textElement)
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

function KatTopBar:ResetTopbarTransparency()
	KatTopBar:SetTopbarTransparency(0.5)
end

function KatTopBar:SetTopbarColor(color)
	if typeof(color) ~= "Color3" then
		return false, "TopBar Color must be a color3"
	end

	if KatTopBar.TopBarColor == color then
		return true
	end

	KatTopBar.TopBarColor = color

	local topbar = GetTopBar()

	if topbar then
		topbar.BackgroundColor3 = color
	end

	colorChangedEvent:Fire(color)

	return true
end

function KatTopBar:GetTopbarColor()
	return KatTopBar.TopBarColor
end

function KatTopBar:ResetTopbarColor()
	KatTopBar:SetTopbarColor(Color3.fromRGB(31, 31, 31))
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

	elementCounter = elementCounter + 1

	local button = {}

	button.ID = elementCounter
	button.Kind = "Button"
	button.Name = config.Name or tostring(elementCounter)

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

		if pressedElement == self then
			pressedElement = nil
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

		UnregisterElement(self)

		self.ClickedEvent:Destroy()
		self.StateChangedEvent:Destroy()

		UpdateButtonPositions()
	end

	table.insert(KatTopBar.Buttons, button)
	RegisterElement(button)

	CreateButtonGui(button)
	UpdateButtonPositions()

	return button
end

function KatTopBar:AddText(config)
	if type(config) ~= "table" then
		return nil, "Configuration must be a table"
	end

	if config.Name ~= nil and type(config.Name) ~= "string" then
		return nil, "Name must be a string"
	end

	if config.Text ~= nil and type(config.Text) ~= "string" then
		return nil, "Text must be a string"
	end

	local textType = config.Type or "left"

	if textType ~= "left" and textType ~= "center" and textType ~= "right" then
		return nil, "Type must be left, center or right"
	end

	if config.Size ~= nil and typeof(config.Size) ~= "UDim2" then
		return nil, "Size must be UDim2"
	end

	if config.Order ~= nil and (type(config.Order) ~= "number" or config.Order < 1) then
		return nil, "Order must be a positive number"
	end

	if config.TextColor ~= nil and typeof(config.TextColor) ~= "Color3" then
		return nil, "TextColor must be Color3"
	end

	if config.Font ~= nil and typeof(config.Font) ~= "EnumItem" then
		return nil, "Font must be an Enum.Font item"
	end

	elementCounter = elementCounter + 1

	local textElement = {}

	textElement.ID = elementCounter
	textElement.Kind = "Text"
	textElement.Name = config.Name or tostring(elementCounter)
	textElement.Text = config.Text or ""
	textElement.Size = config.Size or UDim2.new(0, defaultColumnWidth, 1, 0)
	textElement.Font = config.Font or Enum.Font.SourceSans
	textElement.TextColor = config.TextColor or Color3.new(1, 1, 1)
	textElement.Order = math.floor(config.Order or (#KatTopBar.Texts + 1))
	textElement.Type = textType
	textElement.Visible = config.Visible ~= false
	textElement.Destroyed = false

	textElement.GuiObject = nil
	textElement.TextLabel = nil

	textElement.ClickedEvent = Instance.new("BindableEvent")
	textElement.Clicked = textElement.ClickedEvent.Event

	function textElement:SetText(value)
		if self.Destroyed then
			return false
		end

		if type(value) ~= "string" then
			return false, "Text must be a string"
		end

		self.Text = value

		if self.TextLabel then
			self.TextLabel.Text = value
		end

		return true
	end

	function textElement:SetTextColor(color)
		if self.Destroyed then
			return false
		end

		if typeof(color) ~= "Color3" then
			return false, "TextColor must be Color3"
		end

		self.TextColor = color

		if self.TextLabel then
			self.TextLabel.TextColor3 = color
		end

		return true
	end

	function textElement:SetFont(font)
		if self.Destroyed then
			return false
		end

		if typeof(font) ~= "EnumItem" then
			return false, "Font must be an Enum.Font item"
		end

		self.Font = font

		if self.TextLabel then
			self.TextLabel.Font = font
		end

		return true
	end

	function textElement:SetSize(size)
		if self.Destroyed then
			return false
		end

		if typeof(size) ~= "UDim2" then
			return false, "Size must be UDim2"
		end

		self.Size = size

		if self.GuiObject then
			self.GuiObject.Size = size
		end

		UpdateButtonPositions()

		return true
	end

	function textElement:SetOrder(order)
		if self.Destroyed then
			return false
		end

		if type(order) ~= "number" or order < 1 then
			return false, "Order must be a positive number"
		end

		self.Order = math.floor(order)
		UpdateButtonPositions()

		return true
	end

	function textElement:SetType(newType)
		if self.Destroyed then
			return false
		end

		if newType ~= "left" and newType ~= "center" and newType ~= "right" then
			return false, "Type must be left, center or right"
		end

		self.Type = newType
		UpdateButtonPositions()

		return true
	end

	function textElement:SetVisible(visible)
		if self.Destroyed then
			return false
		end

		if type(visible) ~= "boolean" then
			return false, "Visible must be a boolean"
		end

		self.Visible = visible

		if self.GuiObject then
			self.GuiObject.Visible = visible
		end

		UpdateButtonPositions()

		return true
	end

	function textElement:Destroy()
		if self.Destroyed then
			return
		end

		if pressedElement == self then
			pressedElement = nil
		end

		self.Destroyed = true

		if self.GuiObject then
			self.GuiObject:Destroy()
			self.GuiObject = nil
			self.TextLabel = nil
		end

		for index, existingText in ipairs(KatTopBar.Texts) do
			if existingText == self then
				table.remove(KatTopBar.Texts, index)
				break
			end
		end

		UnregisterElement(self)
		self.ClickedEvent:Destroy()

		UpdateButtonPositions()
	end

	table.insert(KatTopBar.Texts, textElement)
	RegisterElement(textElement)

	CreateTextGui(textElement)
	UpdateButtonPositions()

	return textElement
end

function KatTopBar:AddLeaderstatsColumn(config)
	if type(config) ~= "table" then
		return nil, "Configuration must be a table"
	end

	if config.Name ~= nil and type(config.Name) ~= "string" then
		return nil, "Name must be a string"
	end

	if config.Value ~= nil
		and type(config.Value) ~= "string"
		and type(config.Value) ~= "number" then

		return nil, "Value must be a string or number"
	end

	if config.Order ~= nil
		and (type(config.Order) ~= "number" or config.Order < 1) then

		return nil, "Order must be a positive number"
	end

	if config.NameColor ~= nil and typeof(config.NameColor) ~= "Color3" then
		return nil, "NameColor must be Color3"
	end

	if config.ValueColor ~= nil and typeof(config.ValueColor) ~= "Color3" then
		return nil, "ValueColor must be Color3"
	end

	elementCounter = elementCounter + 1

	local column = {}

	column.ID = elementCounter
	column.Kind = "LeaderstatsColumn"
	column.Name = config.Name or "Column"
	column.Value = config.Value ~= nil and tostring(config.Value) or ""
	column.Order = math.floor(config.Order or (#KatTopBar.LeaderstatsColumns + 1))
	column.Visible = config.Visible ~= false
	column.NameColor = config.NameColor or Color3.new(1, 1, 1)
	column.ValueColor = config.ValueColor or Color3.new(1, 1, 1)
	column.Destroyed = false

	column.LeaderstatsContainer = nil
	column.Column = nil
	column.ColumnName = nil
	column.ColumnValue = nil

	column.ClickedEvent = Instance.new("BindableEvent")
	column.Clicked = column.ClickedEvent.Event

	function column:SetName(name)
		if self.Destroyed then
			return false
		end

		if type(name) ~= "string" then
			return false, "Name must be a string"
		end

		self.Name = name

		if self.ColumnName then
			self.ColumnName.Text = name
		end

		return true
	end

	function column:SetValue(value)
		if self.Destroyed then
			return false
		end

		if type(value) ~= "string" and type(value) ~= "number" then
			return false, "Value must be a string or number"
		end

		self.Value = tostring(value)

		if self.ColumnValue then
			self.ColumnValue.Text = self.Value
		end

		return true
	end

	function column:SetOrder(order)
		if self.Destroyed then
			return false
		end

		if type(order) ~= "number" or order < 1 then
			return false, "Order must be a positive number"
		end

		self.Order = math.floor(order)
		UpdateButtonPositions()

		return true
	end

	function column:SetVisible(visible)
		if self.Destroyed then
			return false
		end

		if type(visible) ~= "boolean" then
			return false, "Visible must be a boolean"
		end

		self.Visible = visible
		UpdateButtonPositions()

		return true
	end

	function column:SetNameColor(color)
		if typeof(color) ~= "Color3" then
			return false, "Color must be Color3"
		end

		self.NameColor = color

		if self.ColumnName then
			self.ColumnName.TextColor3 = color
		end

		return true
	end

	function column:SetValueColor(color)
		if typeof(color) ~= "Color3" then
			return false, "Color must be Color3"
		end

		self.ValueColor = color

		if self.ColumnValue then
			self.ColumnValue.TextColor3 = color
		end

		return true
	end

	function column:Destroy()
		if self.Destroyed then
			return
		end

		if pressedElement == self then
			pressedElement = nil
		end

		self.Destroyed = true

		if self.LeaderstatsContainer then
			self.LeaderstatsContainer:Destroy()
			self.LeaderstatsContainer = nil
		end

		for index, existingColumn in ipairs(KatTopBar.LeaderstatsColumns) do
			if existingColumn == self then
				table.remove(KatTopBar.LeaderstatsColumns, index)
				break
			end
		end

		UnregisterElement(self)

		self.ClickedEvent:Destroy()

		UpdateButtonPositions()
	end

	table.insert(KatTopBar.LeaderstatsColumns, column)
	RegisterElement(column)

	CreateColumnGui(column)
	UpdateButtonPositions()

	return column
end

function KatTopBar:Init()
	if KatTopBar.Initialized then
		warn("KatTopBar is already initialized")
		return false, "Already initialized"
	end

	KatTopBar.Initialized = true

	KatTopBar:MakeTopBar()
	ConnectMouseInput()
	HideOriginalTopBar()

	spawn(function()
		while KatTopBar.Initialized do
			wait(0.25)

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

				if topbar.BackgroundColor3 ~= KatTopBar.TopBarColor then
					topbar.BackgroundColor3 = KatTopBar.TopBarColor
				end

				local expectedPosition = UDim2.new(0, 0, 0, -36)

				if topbar.Position ~= expectedPosition then
					topbar.Position = expectedPosition
				end
			end

			for _, button in ipairs(KatTopBar.Buttons) do
				RestoreButton(button)
			end

			for _, column in ipairs(KatTopBar.LeaderstatsColumns) do
				RestoreColumn(column)
			end

			for _, textElement in ipairs(KatTopBar.Texts) do
				RestoreText(textElement)
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

	while #KatTopBar.LeaderstatsColumns > 0 do
		KatTopBar.LeaderstatsColumns[1]:Destroy()
	end

	while #KatTopBar.Texts > 0 do
		KatTopBar.Texts[1]:Destroy()
	end

	if KatTopBar.Gui then
		KatTopBar.Gui:Destroy()
		KatTopBar.Gui = nil
	end

	return true
end

return KatTopBar
