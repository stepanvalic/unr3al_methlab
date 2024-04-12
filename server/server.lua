currentlab = {}

--Finished
RegisterNetEvent('unr3al_methlab:server:enter', function(methlabId, netId, source)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
	if not DoesEntityExist(entity) then print("noentity") return end

    local response = MySQL.single.await('SELECT locked FROM unr3al_methlab WHERE id = ?', {methlabId}).locked
    if response == 0 then
        SetPlayerRoutingBucket(src, methlabId)
        xPlayer.setCoords(vector3(997.24, -3200.67, -36.39))
        print("set entity coords")
        currentlab[src] = methlabId
        TriggerEvent('unr3al_methlab:server:updatePlayer', src, methlabId, netId, false)
    else
        TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.error, Strings.LabLocked)
    end
end)

--Finished
RegisterNetEvent('unr3al_methlab:server:leave', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
	if not DoesEntityExist(entity) then return end
    SetPlayerRoutingBucket(src, 0)
    local coords = Config.Methlabs[currentlab[src]].Coords
    xPlayer.setCoords(vector3(coords.x, coords.y, coords.z))
    TriggerEvent('unr3al_methlab:server:updatePlayer', src, methlabId, netId, true)
end)

--Finished
RegisterNetEvent('unr3al_methlab:server:openStorage', function(netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end
    exports.ox_inventory:forceOpenInventory(src, 'stash', 'Methlab_Storage_'..currentlab[src])
end)

RegisterNetEvent('unr3al_methlab:server:upgradeStorage', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end

    local storageLevel = MySQL.single.await('SELECT `storage` FROM `unr3al_methlab` WHERE `id` = ?', {methlabId}).storage
    if storageLevel == #Config.Upgrades.Storage then return end
    local canBuy = true
    for itenName, itemCount in pairs(Config.Upgrades.Storage[storageLevel+1].Price) do
        if canBuy then
            local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
            if item < itemCount then
                canBuy = false
            end
        end
    end
    if canBuy then
        for itemName, itemCount in pairs(Config.Upgrades.Storage[storageLevel+1].Price) do
            exports.ox_inventory:RemoveItem(src, itemName, itemCount, false, false, true)
        end
        local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET storage = ? WHERE id = ?', {
            storageLevel+1, methlabId
        })
        if updateOwner == 1 then
            exports.ox_inventory:RegisterStash('Methlab_Storage_'..methlabId, 'Methlab storage', Config.Upgrades.Storage[storageLevel+1].Slots, Config.Upgrades.Storage[storageLevel+1].MaxWeight, false)
            TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.UpgradedStorage)
        end
    else
        return
    end
end)

RegisterNetEvent('unr3al_methlab:server:upgradeSecurity', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end

    local securityLevel = MySQL.single.await('SELECT `security` FROM `unr3al_methlab` WHERE `id` = ?', {methlabId}).security
    if securityLevel == #Config.Upgrades.Security then return end
    local canBuy = true
    for itenName, itemCount in pairs(Config.Upgrades.Security[securityLevel+1].Price) do
        if canBuy then
            local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
            if item < itemCount then
                canBuy = false
            end
        end
    end
    if canBuy then
        for itemName, itemCount in pairs(Config.Upgrades.Security[securityLevel+1].Price) do
            exports.ox_inventory:RemoveItem(src, itemName, itemCount, false, false, true)
        end
        local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET security = ? WHERE id = ?', {
            securityLevel+1, methlabId
        })
        if updateOwner == 1 then
            TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.UpgradedSecurity)
        end



    else
        return
    end
end)

RegisterNetEvent('unr3al_methlab:server:locklab', function(methlabId, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) then return end
    local labId = methlabId
    if currentlab[src] ~= nil then
        labId = currentlab[src]
    end
    local response = MySQL.single.await('SELECT locked FROM unr3al_methlab WHERE id = ?', {methlabId}).locked
    local newlocked = 1
    if response == 1 then
        newlocked = 0
        TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.UnlockedLab)
    else
        TriggerClientEvent('unr3al_methlab:client:notify', src, Config.Noti.success, Strings.LockedLab)
    end
    print(response)
    local updateOwner = MySQL.update.await('UPDATE unr3al_methlab SET locked = ? WHERE id = ?', {
        newlocked, labId
    })
end)

-- Finished
RegisterNetEvent('unr3al_methlab:server:updatePlayer', function(source, methlabId, netId, toDelete)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] ~= methlabId then return end
    local xPlayer = ESX.GetPlayerFromId(src)

    if not toDelete then
        local id = MySQL.insert.await('INSERT INTO unr3al_methlab_people (id, identifier) VALUES (?, ?)', {
            methlabId, xPlayer.identifier,
        })
         
        print(id)
    else
        MySQL.query.await('DELETE FROM unr3al_methlab_people WHERE identifier = @identifier', {
            ['@identifier'] = xPlayer.identifier
        })
        currentlab[src] = nil
    end
end)

-- Finished
AddEventHandler('esx:playerLoaded',function(xPlayer, isNew, skin)
    if xPlayer and not isNew then
        response = MySQL.single.await('SELECT id unr3al_methlab_people WHERE identifier = @identifier', {
            ['@identifier'] = xPlayer.identifier
        })
        if response ~= nil then
            currentlab[src] = response
        end
    end
end)



RegisterNetEvent('unr3al_methlab:server:startprod', function(netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local src = source
	if not DoesEntityExist(entity) or currentlab[src] == nil then return end
    local lab = currentlab[src]
    local recipe = Config.Methlabs[lab].Recipes
    local input = lib.callback.await('unr3al_methlab:client:getMethType', src, netId, recipe)
    print("1"..tostring(input))
    if not input then return end
    if Config.Recipes[recipe][input] ~= nil then
        local canBuy = true
        for itenName, itemCount in pairs(Config.Recipes['standard']['easy'].Ingredients) do
            if canBuy then
                local item = exports.ox_inventory:GetItemCount(src, itenName, false, false)
                if item < itemCount then
                    canBuy = false
                end
            end
        end
        if canBuy then
            for itemName, itemCount in pairs(Config.Recipes[recipe][input].Ingredients) do
                exports.ox_inventory:RemoveItem(src, itemName, itemCount, false, false, true)
            end
            print("yippie")
            local animationComplete = lib.callback.await('unr3al_methlab:client:startAnimation', src, netId)
            if animationComplete then
                print("tewstdfhdgfg")
            end
        else
            print("not yippie")
            return
        end
    end







end)








RegisterCommand("setlab", function(source, args)
    local src = source
    currentlab[src] = 1
end, true)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() == resourceName) then
        local mainTableBuild = MySQL.query.await([[CREATE TABLE IF NOT EXISTS unr3al_methlab (
        `id` int(11) NOT NULL,
        `owned` int(11) NOT NULL DEFAULT 0,
        `owner` varchar(46) DEFAULT NULL,
        `locked` int(11) DEFAULT 1,
        `storage` int(11) NOT NULL DEFAULT 1,
        `security` int(11) NOT NULL DEFAULT 1
        )]])
        if mainTableBuild.warningStatus == 0 then
            Unr3al.Logging('info', 'Database Build for Lab table complete')
        else if mainTableBuild.warningStatus ~= 1 then
            Unr3al.Logging('error', 'Couldnt build Lab table')
        end end
        local response = MySQL.query.await('SELECT * FROM unr3al_methlab')
        for i, methlabId in ipairs(Config.Methlabs) do
            if not response[i] then
                local id = MySQL.insert.await('INSERT INTO unr3al_methlab (id) VALUES (?)', {
                    i
                })
                if id then
                    Unr3al.Logging('debug', 'Inserted data for lab '..i..' into Database')
                else
                    Unr3al.Logging('error', 'Couldnt insert data. Lab: '..i)
                end
            end
            local inventory = exports.ox_inventory:GetInventory('Methlab_Storage_'..i, false)
            if not inventory then
                local methLab = MySQL.single.await('SELECT storage FROM unr3al_methlab WHERE id = ?', {i})
                exports.ox_inventory:RegisterStash('Methlab_Storage_'..i, 'Methlab storage', Config.Upgrades.Storage[methLab.storage].Slots, Config.Upgrades.Storage[methLab.storage].MaxWeight, false)
                print("Registered stash for lab:"..i)
                Unr3al.Logging('debug', 'Registered stash for lab:'..i)
            end
        end
        local secondaryTableBuild = MySQL.query.await([[CREATE TABLE IF NOT EXISTS unr3al_methlab_people (
        `id` int(11) NOT NULL,
        `identifier` varchar(46) DEFAULT NULL
        )]])
        if secondaryTableBuild.warningStatus == 0 then
            Unr3al.Logging('info', 'Database Build for secondary table complete')
        else if secondaryTableBuild.warningStatus ~= 1 then
            Unr3al.Logging('error', 'Couldnt build secondary table')
        end end
    end
end)