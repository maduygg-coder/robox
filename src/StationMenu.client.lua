local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("GasStationAction")
local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")

local gui = Instance.new("ScreenGui")
gui.Name = "GasStationMenu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("ScrollingFrame")
panel.Position = UDim2.fromOffset(12, 14)
panel.BackgroundColor3 = Color3.fromRGB(17, 29, 42)
panel.BorderSizePixel = 0
panel.ScrollBarThickness = 4
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.CanvasSize = UDim2.new()
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.Parent = gui

local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(254, 390)
limit.Parent = panel

local rounding = Instance.new("UICorner")
rounding.CornerRadius = UDim.new(0, 10)
rounding.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local nextRow = 0
local function row(className, height)
	nextRow += 1
	local item = Instance.new(className)
	item.LayoutOrder = nextRow
	item.Size = UDim2.new(1, -3, 0, height)
	item.BackgroundColor3 = Color3.fromRGB(29, 67, 92)
	item.BackgroundTransparency = className == "TextLabel" and 1 or 0
	item.TextColor3 = Color3.fromRGB(239, 247, 255)
	item.TextSize = 15
	item.Font = Enum.Font.GothamMedium
	item.TextWrapped = true
	item.Text = ""
	item.BorderSizePixel = 0
	item.Parent = panel
	return item
end

local money = row("TextLabel", 30)
money.TextSize = 23
money.TextColor3 = Color3.fromRGB(91, 240, 174)
local stock = row("TextLabel", 44)
local toggle = row("TextButton", 34)
local status = row("TextLabel", 42)
status.TextColor3 = Color3.fromRGB(255, 208, 113)
local selectBay = row("TextButton", 33)
local hire = row("TextButton", 33)
local gasOrder = row("TextButton", 33)
local dieselOrder = row("TextButton", 33)
local upgradeGas = row("TextButton", 33)
local upgradeDiesel = row("TextButton", 33)

local expanded = false
local selected = 1
local controls = { status, selectBay, hire, gasOrder, dieselOrder, upgradeGas, upgradeDiesel }

local function number(attribute)
	return player:GetAttribute(attribute) or 0
end

local function orderText(kind, title)
	if player:GetAttribute(kind .. "Ordering") then
		return title .. " đang giao…"
	end

	local liters = math.min(120, number(kind .. "Capacity") - number(kind .. "Stock"))
	if liters <= 0 then
		return "Bể " .. title .. " đang đầy"
	end

	local price = math.ceil(number(kind .. "OrderPrice") * liters / 120)
	return ("Đặt %d L %s · $%d"):format(liters, title, price)
end

local function tankText(kind, title)
	local price = number(kind .. "UpgradePrice")
	if price == 0 then
		return "Bể " .. title .. " · tối đa"
	end
	return ("Bể %s → %d L · $%d"):format(title, number(kind .. "Capacity") * 2, price)
end

local function refresh()
	money.Text = "$" .. cash.Value
	stock.Text = ("Xăng   %d / %d L\nDiesel   %d / %d L"):format(
		number("GasStock"), number("GasCapacity"),
		number("DieselStock"), number("DieselCapacity")
	)

	toggle.Text = expanded and "Thu gọn" or "Mở quản lý trạm"
	panel.Size = expanded and UDim2.new(0.86, 0, 0.76, 0) or UDim2.new(0.86, 0, 0, 140)
	for _, control in ipairs(controls) do
		control.Visible = expanded
	end
	status.Visible = expanded and status.Text ~= ""

	selectBay.Text = ("Chọn trụ  ‹ %d / %d ›"):format(selected, number("OpenPumps"))
	hire.Text = player:GetAttribute("Worker" .. selected)
		and ("Trụ %d đã có nhân viên"):format(selected)
		or ("Thuê cho trụ %d · $%d"):format(selected, number("WorkerPrice"))

	gasOrder.Text = orderText("Gas", "xăng")
	dieselOrder.Text = orderText("Diesel", "diesel")
	upgradeGas.Text = tankText("Gas", "xăng")
	upgradeDiesel.Text = tankText("Diesel", "diesel")
end

toggle.Activated:Connect(function()
	expanded = not expanded
	panel.CanvasPosition = Vector2.zero
	refresh()
end)

selectBay.Activated:Connect(function()
	selected = selected % math.max(1, number("OpenPumps")) + 1
	refresh()
end)

hire.Activated:Connect(function()
	remote:FireServer("hire", selected)
end)

gasOrder.Activated:Connect(function()
	remote:FireServer("order", "Gas")
end)

dieselOrder.Activated:Connect(function()
	remote:FireServer("order", "Diesel")
end)

upgradeGas.Activated:Connect(function()
	remote:FireServer("upgrade", "Gas")
end)

upgradeDiesel.Activated:Connect(function()
	remote:FireServer("upgrade", "Diesel")
end)

remote.OnClientEvent:Connect(function(message)
	status.Text = message
	refresh()
end)

cash:GetPropertyChangedSignal("Value"):Connect(refresh)
player.AttributeChanged:Connect(refresh)
refresh()
