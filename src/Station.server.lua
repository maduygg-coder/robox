local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local START_CASH = 100
local START_PUMPS = 2
local MAX_PUMPS = 6
local MANUAL_SECONDS = 3
local WORKER_SECONDS = 5

local BLUE = Color3.fromRGB(19, 146, 214)
local SILVER = Color3.fromRGB(205, 219, 227)
local DARK = Color3.fromRGB(27, 36, 44)
local WHITE = Color3.fromRGB(242, 248, 251)
local GREEN = Color3.fromRGB(36, 164, 119)

local stations = Instance.new("Folder")
stations.Name = "GasStations"
stations.Parent = workspace

local ownedStations = {}
local usedPlots = {}

local function block(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function faceText(part, message, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(500, 180)
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = WHITE
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = message
	label.Parent = gui
	return label
end

local function promptFor(part, action, seconds)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.HoldDuration = seconds
	prompt.MaxActivationDistance = 9
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function canUse(station, player, part)
	if player ~= station.owner or not station.active then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0
		and (root.Position - part.Position).Magnitude <= 11
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local menuAction = Instance.new("RemoteEvent")
menuAction.Name = "GasStationAction"
menuAction.Parent = ReplicatedStorage

local fuels = {
	Gas = { title = "Xăng", orderPrice = 60 },
	Diesel = { title = "Diesel", orderPrice = 75 },
}

local tankSizes = { 200, 400, 800 }
local tankPrices = { 250, 550 }
local workerPrice = 300
local deliverySeconds = 8

local vehicles = {
	{ name = "Sedan", kind = "Gas", liters = 24, width = 5.8, length = 9.6, roof = 4.5, height = 1.4, cabin = 0.2, pay = 52 },
	{ name = "Hatchback", kind = "Gas", liters = 18, width = 5.4, length = 8.1, roof = 4.6, height = 1.5, cabin = -0.6, pay = 45 },
	{ name = "SUV", kind = "Gas", liters = 32, width = 6.3, length = 10.4, roof = 6.1, height = 1.8, cabin = -0.6, pay = 65 },
	{ name = "Bán tải", kind = "Diesel", liters = 38, width = 6.4, length = 11.5, roof = 4.1, height = 1.7, cabin = 1.5, pay = 79 },
	{ name = "Van", kind = "Diesel", liters = 44, width = 6.1, length = 10.8, roof = 7.6, height = 2.3, cabin = -0.4, pay = 90 },
}

local function carFacing(position, direction)
	-- Đầu xe được dựng về phía +Z của model.
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.pi, 0)
end

local function drive(station, car, waypoints, speed)
	if not station.active then
		return false
	end

	local pose = Instance.new("CFrameValue")
	local changed = pose:GetPropertyChangedSignal("Value"):Connect(function()
		if station.active and car.Parent then
			car:PivotTo(pose.Value)
		end
	end)

	for _, target in ipairs(waypoints) do
		if not station.active or not car.Parent then
			break
		end

		local start = car:GetPivot().Position
		local delta = target - start
		if delta.Magnitude > 0.01 then
			pose.Value = carFacing(start, delta)
			local tween = TweenService:Create(
				pose,
				TweenInfo.new(delta.Magnitude / speed, Enum.EasingStyle.Linear),
				{ Value = carFacing(target, delta) }
			)
			tween:Play()
			tween.Completed:Wait()
			tween:Destroy()
		end
	end

	changed:Disconnect()
	pose:Destroy()
	return station.active and car.Parent ~= nil
end

local function newCar(parent, vehicle, position)
	local model = Instance.new("Model")
	model.Name = vehicle.name

	local w, l = vehicle.width, vehicle.length
	local paint = Color3.fromHSV(math.random(), 0.58, 0.88)
	local glass = Color3.fromRGB(52, 78, 94)
	local chrome = Color3.fromRGB(163, 174, 185)

	local function detail(name, size, x, y, z, color, material)
		local part = block(model, name, size, Vector3.new(x, y, z), color, material)
		part.CanCollide = false
		part.CanTouch = false
		return part
	end

	model.PrimaryPart = detail("Thân xe", Vector3.new(w, 1.35, l), 0, 0, 0, paint, Enum.Material.Metal)
	detail("Cabin", Vector3.new(w - 0.4, vehicle.height, vehicle.roof),
		0, 0.66 + vehicle.height / 2, vehicle.cabin, glass)
	detail("Nóc xe", Vector3.new(w - 0.35, 0.18, vehicle.roof + 0.08),
		0, 0.76 + vehicle.height, vehicle.cabin, paint)
	detail("Ca-pô", Vector3.new(w - 0.18, 0.18, 1.25), 0, 0.72, l / 2 - 0.95, paint)
	detail("Lưới tản nhiệt", Vector3.new(w * 0.44, 0.34, 0.12), 0, -0.03, l / 2 + 0.06, DARK)

	for _, endSign in ipairs({ -1, 1 }) do
		detail("Cản xe", Vector3.new(w, 0.27, 0.28), 0, -0.48, endSign * l / 2, chrome)
	end

	for _, side in ipairs({ -1, 1 }) do
		for _, axle in ipairs({ -1, 1 }) do
			local wheelX = side * w / 2
			local wheelZ = axle * l * 0.31
			local wheel = detail("Lốp", Vector3.new(0.65, 1.85, 1.85),
				wheelX, -0.67, wheelZ, DARK)
			wheel.Shape = Enum.PartType.Cylinder
			local rim = detail("Mâm", Vector3.new(0.08, 1.08, 1.08),
				wheelX + side * 0.34, -0.67, wheelZ, chrome)
			rim.Shape = Enum.PartType.Cylinder
		end

		detail("Đèn trước", Vector3.new(0.95, 0.3, 0.13),
			side * w * 0.36, 0.2, l / 2 + 0.07, WHITE, Enum.Material.Neon)
		detail("Đèn hậu", Vector3.new(0.65, 0.34, 0.13),
			side * w * 0.37, 0.19, -l / 2 - 0.07, Color3.fromRGB(193, 35, 34))
		detail("Gương", Vector3.new(0.45, 0.26, 0.46),
			side * (w / 2 + 0.19), 1.22, vehicle.cabin + vehicle.roof / 2 - 0.38, paint)
		detail("Cột kính", Vector3.new(0.09, vehicle.height, 0.16),
			side * (w / 2 - 0.17), 0.66 + vehicle.height / 2, vehicle.cabin, paint)

		if vehicle.name == "Bán tải" then
			detail("Thành thùng", Vector3.new(0.23, 0.66, 3.3),
				side * (w / 2 - 0.15), 0.98, -l / 2 + 1.75, paint)
		end
	end

	if vehicle.name == "Bán tải" then
		detail("Cửa thùng", Vector3.new(w - 0.25, 0.65, 0.22),
			0, 0.98, -l / 2 + 0.1, paint)
	elseif vehicle.name == "Van" then
		detail("Thân khoang hàng", Vector3.new(w - 0.38, vehicle.height, 4.2),
			0, 0.66 + vehicle.height / 2, -2, paint)
	end

	model:PivotTo(carFacing(position, Vector3.xAxis))
	model.Parent = parent
	return model
end

local function syncFuel(station, kind)
	local tank = station.tanks[kind]
	local owner = station.owner
	owner:SetAttribute(kind .. "Stock", tank.stock)
	owner:SetAttribute(kind .. "Capacity", tankSizes[tank.level])
	owner:SetAttribute(kind .. "OrderPrice", fuels[kind].orderPrice)
	owner:SetAttribute(kind .. "UpgradePrice", tankPrices[tank.level] or 0)
	owner:SetAttribute(kind .. "Ordering", tank.ordering)
end

local function standWorker(station, bay)
	local worker = Instance.new("Model")
	worker.Name = "Nhân viên trụ " .. bay.index
	worker.Parent = station.model

	local base = bay.pump.Position + Vector3.new(-0.5, -3.25, 3)
	local uniform = Color3.fromRGB(31, 127, 194)
	local skin = Color3.fromRGB(231, 173, 124)

	local function body(name, size, offset, color)
		local part = block(worker, name, size, base + offset, color)
		part.CanCollide = false
		return part
	end

	local head = body("Đầu", Vector3.new(1.2, 1.15, 1.05), Vector3.new(0, 4.5, 0), skin)
	faceText(head, "•  •", Enum.NormalId.Back)
	body("Mũ", Vector3.new(1.35, 0.25, 1.2), Vector3.new(0, 5.13, 0), uniform)
	body("Áo", Vector3.new(1.7, 1.8, 0.9), Vector3.new(0, 3, 0), uniform)
	for _, side in ipairs({ -1, 1 }) do
		body("Tay", Vector3.new(0.46, 1.6, 0.56), Vector3.new(side * 1.1, 3, 0), uniform)
		body("Chân", Vector3.new(0.68, 2.08, 0.75), Vector3.new(side * 0.43, 1.05, 0), DARK)
	end
end

local function createStation(player)
	if ownedStations[player] then
		return
	end

	local plot = 0
	while usedPlots[plot] do
		plot += 1
	end
	usedPlots[plot] = true

	local origin = Vector3.new((plot % 3) * 168, 0, math.floor(plot / 3) * 190)
	local model = Instance.new("Model")
	model.Name = "Trạm của " .. player.Name
	model.Parent = stations

	local station = {
		active = true,
		owner = player,
		model = model,
		plot = plot,
		pumps = START_PUMPS,
		bays = {},
	}
	ownedStations[player] = station

	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = START_CASH
	cash.Parent = stats
	station.cash = cash
	station.tanks = {
		Gas = { stock = 200, level = 1, ordering = false },
		Diesel = { stock = 200, level = 1, ordering = false },
	}
	player:SetAttribute("OpenPumps", station.pumps)
	player:SetAttribute("WorkerPrice", workerPrice)
	for kind in pairs(fuels) do
		syncFuel(station, kind)
	end

	local function piece(name, size, x, y, z, color, material)
		return block(model, name, size, origin + Vector3.new(x, y, z), color, material)
	end

	piece("Sân trạm", Vector3.new(146, 1, 134), 0, 0.5, 0, DARK, Enum.Material.Asphalt)
	piece("Quốc lộ", Vector3.new(154, 0.22, 26), 0, 0.97, -80, DARK, Enum.Material.Asphalt)
	piece("Lối vào", Vector3.new(15, 0.22, 17), -64, 0.97, -63, DARK, Enum.Material.Asphalt)
	piece("Lối ra", Vector3.new(13, 0.22, 17), 65, 0.97, -63, DARK, Enum.Material.Asphalt)

	for x = -70, 70, 10 do
		piece("Vạch tim quốc lộ", Vector3.new(5, 0.06, 0.25), x, 1.11, -80,
					Color3.fromRGB(255, 194, 60))
		end

		for _, z in ipairs({ -92, -68 }) do
			piece("Vạch mép quốc lộ", Vector3.new(150, 0.06, 0.22), 0, 1.11, z, WHITE)
		end

		local entrance = piece("Biển lối vào", Vector3.new(8, 3, 0.35), -55, 3.5, -61, BLUE)
		faceText(entrance, "LỐI VÀO")
		local exit = piece("Biển lối ra", Vector3.new(8, 3, 0.35), 57, 3.5, -61, GREEN)
		faceText(exit, "RA QUỐC LỘ")
	piece("Mái bạc", Vector3.new(124, 2, 41), 0, 20, 0, SILVER, Enum.Material.Metal)
	piece("Viền xanh", Vector3.new(125, 0.65, 42), 0, 18.8, 0, BLUE)
	piece("Trần", Vector3.new(120, 0.35, 38), 0, 18.4, 0, WHITE)

	for _, x in ipairs({ -58, 0, 58 }) do
		for _, z in ipairs({ -15, 15 }) do
			piece("Cột mái", Vector3.new(2.6, 17.5, 2.6), x, 9.75, z, SILVER)
		end
	end

	piece("Nền cửa hàng", Vector3.new(94, 0.6, 24), 0, 1.3, 44, SILVER)
	piece("Mái cửa hàng", Vector3.new(94, 1.4, 24), 0, 13, 44, DARK)
	piece("Tường sau", Vector3.new(94, 11, 1), 0, 7, 55.5, SILVER)
	for _, side in ipairs({ -1, 1 }) do
		piece("Tường bên", Vector3.new(1, 11, 24), side * 46.5, 7, 44, SILVER)
		for panel = 1, 4 do
			local x = side * (6 + (panel - 0.5) * 10)
			local glass = piece("Kính mặt tiền", Vector3.new(9.7, 8, 0.45),
				x, 5.6, 32.3, Color3.fromRGB(110, 188, 218), Enum.Material.Glass)
			glass.Transparency = 0.45
			piece("Khung kính", Vector3.new(0.25, 8, 0.6), x + 5 * side, 5.6, 32.3, DARK)

			piece("Kệ hàng", Vector3.new(7, 1, 2), x, 3, 46, DARK)
			for item = 1, 5 do
				piece("Hàng trưng bày", Vector3.new(0.8, 1.1, 0.8),
					x - 3 + item, 4.05, 46, Color3.fromHSV(item / 6, 0.7, 0.92))
			end
		end
	end

	local storeSign = piece("Biển cửa hàng", Vector3.new(92, 2.8, 0.6),
		0, 11.1, 32, BLUE)
	faceText(storeSign, "MART  •  CỬA HÀNG TIỆN LỢI")

	local brand = piece("Biển trạm", Vector3.new(41, 2.8, 0.8),
		0, 20, -21, BLUE)
	faceText(brand, "GAS STATION  •  " .. player.DisplayName)

	local function pumpPrice()
		return 175 + (station.pumps - START_PUMPS) * 125
	end

	local pumpDesk = piece("Bảng mở trụ", Vector3.new(8, 4, 1), 15, 3, 39, BLUE)
	local pumpLabel = faceText(pumpDesk, "")
	local buyPrompt = promptFor(pumpDesk, "Mở trụ tiếp theo", 0.25)

	local function refreshDesks()
		pumpLabel.Text = station.pumps == MAX_PUMPS and "Đã mở cả 6 trụ"
			or ("Trụ %d/%d\nMở thêm $%d"):format(station.pumps, MAX_PUMPS, pumpPrice())
		buyPrompt.Enabled = station.pumps < MAX_PUMPS
		player:SetAttribute("OpenPumps", station.pumps)
	end

	local function refreshBay(bay)
		local vehicle = bay.vehicle
		local supplied = station.tanks[vehicle.kind].stock >= vehicle.liters
		bay.prompt.Enabled = supplied and not bay.worker
		local demand = ("%s · %d L %s"):format(vehicle.name, vehicle.liters, fuels[vehicle.kind].title)
		bay.label.Text = demand .. (supplied and "\nXe đang chờ" or "\nThiếu nhiên liệu")
	end

	local function beginFuel(bay, automatic)
		if not station.active or bay.state ~= "waiting" or bay.worker ~= automatic then
			return
		end

		local vehicle = bay.vehicle
		local tank = station.tanks[vehicle.kind]
		if tank.stock < vehicle.liters then
			refreshBay(bay)
			return
		end

		bay.state = "fueling"
		bay.prompt.Enabled = false
		tank.stock -= vehicle.liters
		syncFuel(station, vehicle.kind)
		bay.label.Text = automatic and "Nhân viên đang đổ" or "Đang thanh toán"

		task.delay(automatic and WORKER_SECONDS or 0, function()
			if station.active then
				cash.Value += vehicle.pay
				bay.label.Text = "Đã thanh toán\n+$" .. vehicle.pay
				bay.state = "paid"
			end
		end)
	end

	local function useRoad(car, points, speed)
		-- Chỉ một xe di chuyển trên các đoạn đường dùng chung trong trạm.
		while station.active and station.roadBusy do
			task.wait(0.1)
		end
		if not station.active then
			return false
		end

		station.roadBusy = true
		local arrived = drive(station, car, points, speed)
		station.roadBusy = false
		return arrived
	end

	local function openBay(bay)
		bay.pump.Color = SILVER
		bay.cap.Color = BLUE
		bay.label.Text = "Đợi khách"

		local function point(x, z)
			return origin + Vector3.new(x, 2.63, z)
		end

		task.spawn(function()
			task.wait(math.random(1, 4))

			while station.active do
				bay.state = "arriving"
				bay.label.Text = "Xe đang vào"
				local vehicle = vehicles[math.random(1, #vehicles)]
				local start = point(-76, -74)
				local car = newCar(model, vehicle, start)
				-- Ẩn xe đang chờ quyền vào đường dùng chung.
				car.Parent = nil
				while station.active and station.roadBusy do
					task.wait(0.1)
				end
				if not station.active then
					car:Destroy()
					return
				end
				car.Parent = model

				if not useRoad(car, {
					point(-64, -74), point(-64, -40),
					point(bay.x, -40), point(bay.x, 0),
					}, 24) then
					return
				end

				bay.vehicle = vehicle
				bay.state = "waiting"
				repeat
					if bay.state == "waiting" then
						refreshBay(bay)
						if bay.worker then
							beginFuel(bay, true)
						end
					end
					task.wait(0.25)
				until not station.active or bay.state == "paid"

				if not station.active then
					return
				end

				bay.state = "departing"
				if not useRoad(car, {
					point(bay.x, 25), point(65, 25), point(65, -74), point(76, -74),
					}, 25) then
					return
				end

				car:Destroy()
				bay.label.Text = "Đợi khách"
				task.wait(math.random(2, 5))
			end
		end)
	end

	for index = 1, MAX_PUMPS do
		local x = -45 + (index - 1) * 18
		local pumpX = x - 5.6
		local lamp = piece("Đèn mái", Vector3.new(5, 0.15, 2),
			x, 18.15, 0, WHITE, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Brightness = 0.9
		light.Range = 22
		light.Parent = lamp

		piece("Vạch làn", Vector3.new(0.22, 0.06, 79), x + 8, 1.04, -13, WHITE)
		piece("Đảo trụ", Vector3.new(4.3, 0.35, 12), pumpX, 1.18, 0, SILVER)
		local pump = piece("Trụ xăng " .. index, Vector3.new(3.4, 5.9, 2.6),
			pumpX, 4.25, 0, DARK)
		local cap = piece("Nắp trụ", Vector3.new(3.8, 0.55, 2.9), pumpX, 7.2, 0, DARK)
		local screen = piece("Màn hình trụ", Vector3.new(2.85, 2, 0.15),
			pumpX, 5.15, -1.36, DARK)
		piece("Vòi bơm", Vector3.new(0.35, 1.15, 0.4),
			pumpX + 1.35, 3.75, -1.45, BLUE)

		local grade = index % 2 == 0 and "RON 95" or "RON 92"
		local prompt = promptFor(pump, "Đổ nhiên liệu", MANUAL_SECONDS)
		prompt.ObjectText = "Trụ " .. index
		prompt.Enabled = false

		local bay = {
			x = x,
			index = index,
			worker = false,
			pump = pump,
			cap = cap,
			label = faceText(screen, grade .. "\nChưa mở"),
			prompt = prompt,
			state = "closed",
		}
		station.bays[index] = bay

		prompt.Triggered:Connect(function(visitor)
			if canUse(station, visitor, pump) then
				beginFuel(bay, false)
			end
		end)
	end

	buyPrompt.Triggered:Connect(function(visitor)
		if not canUse(station, visitor, pumpDesk) or station.pumps >= MAX_PUMPS then
			return
		end
		local price = pumpPrice()
		if cash.Value >= price then
			cash.Value -= price
			station.pumps += 1
			openBay(station.bays[station.pumps])
			refreshDesks()
		end
	end)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Điểm hồi sinh"
	spawn.Size = Vector3.new(5, 1, 5)
	spawn.Position = origin + Vector3.new(-64, 1.5, -25)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = model
	player.RespawnLocation = spawn
	if player.Character then
		player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end

	refreshDesks()
	for index = 1, station.pumps do
		openBay(station.bays[index])
	end
end

Players.PlayerRemoving:Connect(function(player)
	local station = ownedStations[player]
	if station then
		station.active = false
		station.model:Destroy()
		ownedStations[player] = nil
		usedPlots[station.plot] = nil
	end
end)

Players.PlayerAdded:Connect(createStation)
for _, player in ipairs(Players:GetPlayers()) do
	createStation(player)
end

local function notify(player, message)
	menuAction:FireClient(player, message)
end

menuAction.OnServerEvent:Connect(function(player, action, selection)
	local station = ownedStations[player]
	if not station or not station.active then
		return
	end

	if action == "hire" then
		if typeof(selection) ~= "number" or selection % 1 ~= 0
			or selection < 1 or selection > station.pumps then
			return
		end

		local bay = station.bays[selection]
		if bay.worker then
			notify(player, "Trụ này đã có nhân viên.")
		elseif station.cash.Value < workerPrice then
			notify(player, "Bạn cần $" .. workerPrice .. " để thuê.")
		else
			station.cash.Value -= workerPrice
			bay.worker = true
			bay.prompt.Enabled = false
			player:SetAttribute("Worker" .. selection, true)
			standWorker(station, bay)
			notify(player, "Đã thuê nhân viên cho trụ " .. selection .. ".")
		end
		return
	end

	if (action ~= "order" and action ~= "upgrade")
		or (selection ~= "Gas" and selection ~= "Diesel") then
		return
	end

	local tank = station.tanks[selection]
	local capacity = tankSizes[tank.level]
	local title = fuels[selection].title

	if action == "order" then
		if tank.ordering then
			notify(player, "Đơn " .. title .. " đang giao.")
			return
		end
		if tank.stock == capacity then
			notify(player, "Bể " .. title .. " đang đầy.")
			return
		end

		local liters = math.min(120, capacity - tank.stock)
		local price = math.ceil(fuels[selection].orderPrice * liters / 120)
		if station.cash.Value < price then
			notify(player, "Bạn cần $" .. price .. " để đặt hàng.")
			return
		end

		station.cash.Value -= price
		tank.ordering = true
		syncFuel(station, selection)
		notify(player, ("Đã đặt %d L %s. Giao sau %d giây."):format(liters, title, deliverySeconds))

		task.delay(deliverySeconds, function()
			if station.active then
				tank.stock += liters
				tank.ordering = false
				syncFuel(station, selection)
				notify(player, ("Đã giao %d L %s."):format(liters, title))
			end
		end)
	else
		local price = tankPrices[tank.level]
		if not price then
			notify(player, "Bể này đã đạt 800 L.")
		elseif station.cash.Value < price then
			notify(player, "Bạn cần $" .. price .. " để nâng bể.")
		else
			station.cash.Value -= price
			tank.level += 1
			syncFuel(station, selection)
			notify(player, ("Bể %s đã nâng lên %d L."):format(title, tankSizes[tank.level]))
	end
end
end)
