local RSGCore = exports['rsg-core']:GetCoreObject()
-------------------
local entities = {}
local npcs = {}
-------------------
local timeout = false
local timeoutTimer = 30
local horsePed = 0
local horseSpawned = false
local HorseCalled = false
local newnames = ''
local horseDBID
local horsexp = nil
local horsegender = nil
local horseBonding = 0
local bondingLevel = 0
-------------------
local ped 
local coords
local hasSpawned = false
local lanternequiped = false
local lanternUsed = false
local holsterequiped = false
local holsterUsed = false
-------------------
local Zones = {}
local zonename = nil
local inStableZone = false
-------------------

-- Export for Horse Bonding Level checks
exports('CheckHorseBondingLevel', function()
    return bondingLevel
end)

-- Export for active horsePed
exports('CheckActiveHorse', function()
    return horsePed
end)

RegisterNetEvent('rsg-horses:client:custShop', function()
    local function createCamera(horsePed)
        local coords = GetEntityCoords(horsePed)
        CustomHorse()
        groundCam = CreateCam("DEFAULT_SCRIPTED_CAMERA")
        SetCamCoord(groundCam, coords.x + 0.5, coords.y - 3.6, coords.z )
        SetCamRot(groundCam, 10.0, 0.0, 0 + 20)
        SetCamActive(groundCam, true)
        RenderScriptCams(true, false, 1, true, true)
        fixedCam = CreateCam("DEFAULT_SCRIPTED_CAMERA")
        SetCamCoord(fixedCam, coords.x + 0.5,coords.y - 3.6,coords.z+1.8)
        SetCamRot(fixedCam, -20.0, 0, 0 + -10.0)
        SetCamActive(fixedCam, true)
        SetCamActiveWithInterp(fixedCam, groundCam, 3900, true, true)
        Wait(3900)
        DestroyCam(groundCam)
    end
    if horsePed ~= 0 then
        local pcoords = GetEntityCoords(PlayerPedId())
        local coords = GetEntityCoords(horsePed)
        if #(pcoords - coords) <= 30.0 then
            createCamera(horsePed)
        else
            RSGCore.Functions.Notify(Lang:t('error.horse_too_far'), 'error', 7500)
        end 
    else 
        RSGCore.Functions.Notify('No Horse Detected', 'error', 7500)
    end
end)

-- rename horse name command
RegisterCommand('sethorsename',function()
    local input = exports['rsg-input']:ShowInput({
        header = "Name your horse",
        submitText = "Confirm",
        inputs = {
            {
                type = 'text',
                isRequired = true,
                name = 'realinput',
                text = 'text'
            }
        }
    })

    if input == nil then return end

    TriggerServerEvent('rsg-horses:renameHorse', input.realinput)
end)

-- create stable zones
CreateThread(function() 
    for k=1, #Config.StableZones do
        Zones[k] = PolyZone:Create(Config.StableZones[k].zones, {
            name = Config.StableZones[k].name,
            minZ = Config.StableZones[k].minz,
            maxZ = Config.StableZones[k].maxz,
            debugPoly = false,
        })
        Zones[k]:onPlayerInOut(function(isPointInside)
            if isPointInside then
                inStableZone = true
                zonename = Zones[k].name
                TriggerEvent('rsg-horses:client:triggerStable', zonename)
            else
                inStableZone = false
                TriggerEvent('rsg-horses:client:distroyStable')
            end
        end)
    end
end)

-- trigger stables and create peds and horses
RegisterNetEvent('rsg-horses:client:triggerStable', function(zone)
    if inStableZone == true then
        for k,v in pairs(Config.BoxZones) do
            if k == zone then
                for j, n in pairs(v) do
                    Wait(1)
                    local model = GetHashKey(n.model)
                    while (not HasModelLoaded(model)) do
                        RequestModel(model)
                        Wait(1)
                    end
                    local entity = CreatePed(model, n.coords.x, n.coords.y, n.coords.z-1, n.heading, false, true, 0, 0)
                    while not DoesEntityExist(entity) do
                        Wait(1)
                    end
                    local hasSpawned = true
                    table.insert(entities, entity)
                    Citizen.InvokeNative(0x283978A15512B2FE, entity, true)
                    FreezeEntityPosition(entity, true)
                    SetEntityCanBeDamaged(entity, false)
                    SetEntityInvincible(entity, true)
                    SetBlockingOfNonTemporaryEvents(npc, true)
                    Citizen.InvokeNative(0xC80A74AC829DDD92, entity, GetPedRelationshipGroupHash(entity))
                    Citizen.InvokeNative(0xBF25EB89375A37AD, 1, GetPedRelationshipGroupHash(entity), `PLAYER`)
                    exports['rsg-target']:AddTargetEntity(entity, {
                        options = {
                            {
                                icon = "fas fa-horse-head",
                                label =  n.names.." || " .. n.price ..  "$",
                                targeticon = "fas fa-eye",
                                action = function(newnames)
                                    local dialog = exports['rsg-input']:ShowInput({
                                        header = Lang:t('menu.horse_setup'),
                                        submitText = Lang:t('menu.horse_buy'),
                                        inputs = {
                                            {
                                                text = Lang:t('menu.horse_name'),
                                                name = "horsename",
                                                type = "text",
                                                isRequired = true,
                                            },
                                            {
                                                text = Lang:t('menu.horse_gender'),
                                                name = "horsegender",
                                                type = "radio",
                                                options = {
                                                    { value = "male",   text = Lang:t('menu.horse_male') },
                                                    { value = "female", text = Lang:t('menu.horse_female') },
                                                },
                                            },
                                        }
                                    })
                                    if dialog ~= nil then
                                        for k,v in pairs(dialog) do
                                            newhorsename = dialog.horsename
                                            newhorsegender = dialog.horsegender
                                        end
                                    end
                                    if newhorsename ~= nil then
                                        TriggerServerEvent('rsg-horses:server:BuyHorse', n.price, n.model, newhorsename, newhorsegender)
                                    else
                                        return
                                    end
                                end
                            }
                        },
                        distance = 2.5,
                    })
                    Citizen.InvokeNative(0x9587913B9E772D29, entity, 0)
                    SetModelAsNoLongerNeeded(model)
                end
            else 
            end
        end
        for key,value in pairs(Config.ModelSpawns) do
            while not HasModelLoaded(value.model) do
                RequestModel(value.model)
                Wait(1)
            end
            local ped = CreatePed(value.model, value.coords.x, value.coords.y, value.coords.z - 1.0, value.heading, false, false, 0, 0)
            while not DoesEntityExist(ped) do
                Wait(1)
            end
            Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
            SetEntityCanBeDamaged(ped, false)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            Wait(1)
            exports['rsg-target']:AddTargetEntity(ped, {
                options = {
                    {
                        icon = "fas fa-horse-head",
                        label = Lang:t('menu.horse_view_horses'),
                        targeticon = "fas fa-eye",
                        action = function()
                            TriggerEvent("rsg-horses:client:menu")
                        end
                    },
                    {
                        icon = "fas fa-horse-head",
                        label = Lang:t('menu.horse_store_horse'),
                        targeticon = "fas fa-eye",
                        action = function()
                            TriggerEvent("rsg-horses:client:storehorse")
                        end
                    },
                    {
                        icon = "fas fa-horse-head",
                        label = Lang:t('menu.horse_sell'),
                        targeticon = "fas fa-eye",
                        action = function()
                            TriggerEvent("rsg-horses:client:MenuDel")
                        end
                    },
                    {
                        icon = "fas fa-horse-head",
                        label =  Lang:t('menu.horse_customize'),
                        targeticon = "fas fa-eye",
                        action = function()
                        TriggerEvent('rsg-horses:client:custShop')
                        end
                    },
                    {
                        icon = "fas fa-horse-head",
                        label =  Lang:t('menu.horse_trade'),
                        targeticon = "fas fa-eye",
                        action = function()
                        TriggerEvent('rsg-horses:client:tradehorse')
                        end
                    },
                    {
                        icon = "fas fa-award",
                        label =  Lang:t('menu.horse_trainer_shop'),
                        targeticon = "fas fa-eye",
                        action = function()
                        TriggerEvent('rsg-horsetrainer:client:OpenTrainerShop')
                        end
                    },
                },
                distance = 2.5,
            })
            SetModelAsNoLongerNeeded(value.model)
            table.insert(npcs, ped)
        end
    end
end)

-- destroy stable/npcs once left zone
RegisterNetEvent('rsg-horses:client:distroyStable', function()
    for k,v in pairs(entities) do
        DeletePed(v)
        SetEntityAsNoLongerNeeded(v)
    end
    for k,v in pairs(npcs) do
        DeletePed(v)
        SetEntityAsNoLongerNeeded(v)
    end
end)

-- trade horse
local function TradeHorse()
    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data,newnames)
        if horsePed ~= 0 then
            local player, distance = RSGCore.Functions.GetClosestPlayer()
            if player ~= -1 and distance < 1.5 then
                local playerId = GetPlayerServerId(player)
                local horseId = data.citizenid
                TriggerServerEvent('rsg-horses:server:TradeHorse', playerId, horseId)
                RSGCore.Functions.Notify(Lang:t('success.horse_traded'), 'success', 7500)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_nearby_player'), 'success', 7500)
            end
        end
    end)
end

-- place on ground properly
local function PlacePedOnGroundProperly(hPed)
    local playerPed = PlayerPedId()
    local howfar = math.random(15, 30)
    local x, y, z = table.unpack(GetEntityCoords(playerPed))
    local found, groundz, normal = GetGroundZAndNormalFor_3dCoord(x - howfar, y, z)

    if found then
        SetEntityCoordsNoOffset(hPed, x - howfar, y, groundz + normal.z, true)
    end
end

-- calculate horse bonding levels
local function BondingLevels()
    local maxBonding = GetMaxAttributePoints(horsePed, 7)
    local currentBonding = GetAttributePoints(horsePed, 7)
    local thirdBonding = maxBonding / 3

    if currentBonding >= maxBonding then
        bondingLevel = 4
    end

    if currentBonding >= thirdBonding and thirdBonding * 2 > currentBonding then
        bondingLevel = 2
    end

    if currentBonding >= thirdBonding * 2 and maxBonding > currentBonding  then
        bondingLevel = 3
    end

    if thirdBonding > currentBonding then
        bondingLevel = 1
    end
end

-- spawn horse
local function SpawnHorse()
    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data)
        if (data) then
            local ped = PlayerPedId()
            local model = GetHashKey(data.horse)
            local location = GetEntityCoords(ped)

            if (location) then
                while not HasModelLoaded(model) do
                    RequestModel(model)
                    Wait(10)
                end

                local heading = 300

                SetEntityAsMissionEntity(horsePed, false, false)
                SetModelAsNoLongerNeeded(model)
                SetEntityAsNoLongerNeeded(horsePed)
                DeleteEntity(horsePed)
                DeletePed(horsePed)

                horsePed = 0

                horsePed = CreatePed(model, location.x - 30, location.y, location.z, heading, true, true, 0, 0)
                SetEntityCanBeDamaged(horsePed, false)
                Citizen.InvokeNative(0x9587913B9E772D29, horsePed, false)
                PlacePedOnGroundProperly(horsePed)

                local horseCoords = GetEntityCoords(horsePed)

                while not DoesEntityExist(horsePed) do
                    Wait(10)
                end

                getControlOfEntity(horsePed)

                Citizen.InvokeNative(0x283978A15512B2FE, horsePed, true) -- SetRandomOutfitVariation
                local horseBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, horsePed) -- BlipAddForEntity
                Citizen.InvokeNative(0x9CB1A1623062F402, horseBlip, data.name) -- SetBlipName
                Citizen.InvokeNative(0x931B241409216C1F, ped, horsePed, true) -- SetPedOwnsAnimal

                -- set relationship group between horse and player
                Citizen.InvokeNative(0xC80A74AC829DDD92, horsePed, GetPedRelationshipGroupHash(horsePed)) -- SetPedRelationshipGroupHash
                Citizen.InvokeNative(0xBF25EB89375A37AD, 1, GetPedRelationshipGroupHash(horsePed), `PLAYER`) -- SetRelationshipBetweenGroups
                if Config.Debug then
                    local relationship = Citizen.InvokeNative(0x9E6B70061662AE5C, GetPedRelationshipGroupHash(horsePed), `PLAYER`) -- GetRelationshipBetweenGroups
                    print(relationship)
                end
                -- end of relationship group

                SetModelAsNoLongerNeeded(model)
                SetEntityAsNoLongerNeeded(horsePed)
                SetEntityAsMissionEntity(horsePed, true)
                SetEntityCanBeDamaged(horsePed, true)
                SetPedNameDebug(horsePed, data.name)
                SetPedPromptName(horsePed, data.name)

                -- set horse components
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.saddle), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.blanket), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.saddlebag), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.bedroll), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.horn), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.stirrup), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.mane), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.tail), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.mask), true, true, true) -- ApplyShopItemToPed
                Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, tonumber(data.mustache), true, true, true) -- ApplyShopItemToPed
                SetPedConfigFlag(horsePed, 297, true) -- PCF_ForceInteractionLockonOnTargetPed
                Citizen.InvokeNative(0xCC97B29285B1DC3B, horsePed, 1) -- SetAnimalMood

                -- set horse xp and gender
                horsexp = data.horsexp
                horsegender = data.gender

                -- set horse health/stamina/ability/speed/acceleration (increased by horse training)
                if horsexp <= 99 then
                    SetAttributePoints(horsePed, 0, Config.Level1) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level1) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level1) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level1) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level1) -- ACCELERATION (0-2000)
                elseif horsexp >= 100 and horsexp <= 199 then
                    SetAttributePoints(horsePed, 0, Config.Level2) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level2) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level2) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level2) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level2) -- ACCELERATION (0-2000)
                elseif horsexp >= 200 and horsexp <= 299 then
                    SetAttributePoints(horsePed, 0, Config.Level3) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level3) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level3) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level3) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level3) -- ACCELERATION (0-2000)
                elseif horsexp >= 300 and horsexp <= 399 then
                    SetAttributePoints(horsePed, 0, Config.Level4) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level4) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level4) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level4) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level4) -- ACCELERATION (0-2000)
                elseif horsexp >= 400 and horsexp <= 499 then
                    SetAttributePoints(horsePed, 0, Config.Level5) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level5) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level5) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level5) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level5) -- ACCELERATION (0-2000)
                elseif horsexp >= 500 and horsexp <= 999 then
                    SetAttributePoints(horsePed, 0, Config.Level6) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level6) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level6) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level6) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level6) -- ACCELERATION (0-2000)
                elseif horsexp >= 1000 and horsexp <= 1999 then
                    SetAttributePoints(horsePed, 0, Config.Level7) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level7) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level7) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level7) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level7) -- ACCELERATION (0-2000)
                elseif horsexp >= 2000 and horsexp <= 2999 then
                    SetAttributePoints(horsePed, 0, Config.Level8) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level8) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level8) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level8) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level8) -- ACCELERATION (0-2000)
                elseif horsexp >= 3000 and horsexp <= 3999 then
                    SetAttributePoints(horsePed, 0, Config.Level9) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level9) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level9) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level9) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level9) -- ACCELERATION (0-2000)
                elseif horsexp >= 4000 then
                    SetAttributePoints(horsePed, 0, Config.Level10) -- HEALTH (0-2000)
                    SetAttributePoints(horsePed, 1, Config.Level10) -- STAMINA (0-2000)
                    SetAttributePoints(horsePed, 4, Config.Level10) -- AGILITY (0-2000)
                    SetAttributePoints(horsePed, 5, Config.Level10) -- SPEED (0-2000)
                    SetAttributePoints(horsePed, 6, Config.Level10) -- ACCELERATION (0-2000)
                    -- overpower settings
                    EnableAttributeOverpower(horsePed, 0, 5000.0) -- health overpower
                    EnableAttributeOverpower(horsePed, 1, 5000.0) -- stamina overpower
                    local setoverpower = data.horsexp + .0 -- convert overpower to float value
                    Citizen.InvokeNative(0xF6A7C08DF2E28B28, horsePed, 0, setoverpower) -- set health with overpower
                    Citizen.InvokeNative(0xF6A7C08DF2E28B28, horsePed, 1, setoverpower) -- set stamina with overpower
                    -- end of overpower settings
                end
                -- end set horse health/stamina/ability/speed/acceleration (increased by horse training)

                -- horse bonding level: start
                if horsexp <= Config.MaxBondingLevel * 0.25 then -- level 1 (0 -> 1250)
                    horseBonding = 1
                end

                if horsexp >= Config.MaxBondingLevel * 0.5 then -- level 2 (1000 -> 2500)
                    horseBonding = 817
                end

                if horsexp >= Config.MaxBondingLevel * 0.75 then -- level 3 (2500 -> 3750)
                    horseBonding = 1634
                end

                if horsexp >= Config.MaxBondingLevel then -- level 4 (3750 -> 5000)
                    horseBonding = 2450
                end

                Citizen.InvokeNative(0x09A59688C26D88DF, horsePed, 7, horseBonding)

                BondingLevels()
                -- horse bonding level: end

                local faceFeature = 0.0

                -- set gender of horse
                if horsegender ~= 'male' then
                    faceFeature = 1.0
                end

                Citizen.InvokeNative(0x5653AB26C82938CF, horsePed, 41611, faceFeature)
                Citizen.InvokeNative(0xCC8CA3E88256E58F, horsePed, false, true, true, true, false)

                horseSpawned = true
                HorseCalled = true

                moveHorseToPlayer()
            end
        end
    end)
end

----------------------------------------------------------------------------------------------------

local blanketsHash
local saddlesHash
local hornsHash
local saddlebagsHash
local stirrupsHash
local bedrollsHash
local tailsHash
local manesHash
local masksHash
local mustachesHash

MenuData = {}
TriggerEvent('menu_base:getData',function(call)
    MenuData = call
end)

function CustomHorse()
    MenuData.CloseAll()
    local elements = {
            {label = Lang:t('menu.custom_blankets'),    category = 'blankets',   value = 1, desc = "press [enter] to apply",   type = "slider", min = 1, max = 65},
            {label = Lang:t('menu.custom_saddles'),     category = 'saddles',    value = 1, desc = "press [enter] to apply",   type = "slider", min = 1, max = 136},
            {label = Lang:t('menu.custom_horns'),       category = 'horns',      value = 1, desc = "press [enter] to apply",   type = "slider", min = 1, max = 14},
            {label = Lang:t('menu.custom_saddle_bags'), category = 'saddlebags', value = 1, desc = "press [enter] to apply",   type = "slider", min = 1, max = 20},
            {label = Lang:t('menu.custom_stirrups'),    category = 'stirrups',   value = 1, desc = "press [enter] to apply",   type = "slider", min = 1, max = 11},
            {label = Lang:t('menu.custom_bedrolls'),    category = 'bedrolls',   value = 1, desc = "press [enter] to apply",   type = "slider", min = 1, max = 30},
            {label = Lang:t('menu.custom_tails'),       category = 'tails',      value = 1, desc = "press [enter] to apply",   type = "slider", min = 1, max = 85},
            {label = Lang:t('menu.custom_manes'),       category = 'manes',      value = 1, desc = "press [enter] to apply",   type = "slider", min = 1, max = 102},
            {label = Lang:t('menu.custom_masks'),       category = 'masks',      value = 0, desc = "select 0 for no mask",     type = "slider", min = 0, max = 51},
            {label = Lang:t('menu.custom_mustaches'),   category = 'mustaches',  value = 0, desc = "select 0 for no mustache", type = "slider", min = 0, max = 16},
        }
        MenuData.Open(
        'default', GetCurrentResourceName(), 'horse_menu',
        {
            title    = Lang:t('menu.horse_customization'),
            subtext  = '',
            align    = 'top-left',
            elements = elements,
        },
        function(data, menu)
            if data.current.category == 'blankets' then
                TriggerEvent('rsg-horses:client:setBlankets', data.current.category, data.current.value)
            end
            if data.current.category == 'saddles' then
                TriggerEvent('rsg-horses:client:setSaddles', data.current.category, data.current.value)
            end
            if data.current.category == 'horns' then
                TriggerEvent('rsg-horses:client:setHorns', data.current.category, data.current.value)
            end
            if data.current.category == 'saddlebags' then
                TriggerEvent('rsg-horses:client:setSaddlebags', data.current.category, data.current.value)
            end
            if data.current.category == 'stirrups' then
                TriggerEvent('rsg-horses:client:setStirrups', data.current.category, data.current.value)
            end
            if data.current.category == 'bedrolls' then
                TriggerEvent('rsg-horses:client:setBedrolls', data.current.category, data.current.value)
            end
            if data.current.category == 'tails' then
                TriggerEvent('rsg-horses:client:setTails', data.current.category, data.current.value)
            end
            if data.current.category == 'manes' then
                TriggerEvent('rsg-horses:client:setManes', data.current.category, data.current.value)
            end
            if data.current.category == 'masks' then
                TriggerEvent('rsg-horses:client:setMasks', data.current.category, data.current.value)
            end
            if data.current.category == 'mustaches' then
                TriggerEvent('rsg-horses:client:setMustaches', data.current.category, data.current.value)
            end
        end,
        function(data, menu)
        menu.close()
        TriggerEvent('rsg-horses:closeMenu')
    end)
end

-- handle blankets compontent
RegisterNetEvent('rsg-horses:client:setBlankets',function(category, value)
    if category == 'blankets' then
        for k, v in pairs(Components.HorseBlankets) do
            if value == v.hashid then
                blanketsHash = v.hash
            end
        end
        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
        local ped = PlayerPedId()
        local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
            if mount ~= nil then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(blanketsHash), true, true, true) 
                TriggerServerEvent('rsg-horses:server:SaveBlankets', blanketsHash)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
            end
        end)
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle saddles compontent
RegisterNetEvent('rsg-horses:client:setSaddles',function(category, value)
    if category == 'saddles' then
        for k, v in pairs(Components.HorseSaddles) do
            if value == v.hashid then
                saddlesHash = v.hash
            end
        end
        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
        local ped = PlayerPedId()
        local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
            if mount ~= nil then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(saddlesHash), true, true, true) 
                TriggerServerEvent('rsg-horses:server:SaveSaddles', saddlesHash)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
            end
        end)
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle horns compontent
RegisterNetEvent('rsg-horses:client:setHorns',function(category, value)
    if category == 'horns' then
        for k, v in pairs(Components.HorseHorns) do
            if value == v.hashid then
                hornsHash = v.hash
            end
        end
        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
        local ped = PlayerPedId()
        local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
            if mount ~= nil then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(hornsHash), true, true, true) 
                TriggerServerEvent('rsg-horses:server:SaveHorns', hornsHash)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
            end
        end)
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle saddlebags compontent
RegisterNetEvent('rsg-horses:client:setSaddlebags',function(category, value)
    if category == 'saddlebags' then
        for k, v in pairs(Components.HorseSaddlebags) do
            if value == v.hashid then
                saddlebagsHash = v.hash
            end
        end
        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
        local ped = PlayerPedId()
        local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
            if mount ~= nil then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(saddlebagsHash), true, true, true) 
                TriggerServerEvent('rsg-horses:server:SaveSaddlebags', saddlebagsHash)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
            end
        end)
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle stirrups compontent
RegisterNetEvent('rsg-horses:client:setStirrups',function(category, value)
    if category == 'stirrups' then
        for k, v in pairs(Components.HorseStirrups) do
            if value == v.hashid then
                stirrupsHash = v.hash
            end
        end
        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
        local ped = PlayerPedId()
        local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
            if mount ~= nil then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(stirrupsHash), true, true, true) 
                TriggerServerEvent('rsg-horses:server:SaveStirrups', stirrupsHash)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
            end
        end)
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle bedrolls compontent
RegisterNetEvent('rsg-horses:client:setBedrolls',function(category, value)
    if category == 'bedrolls' then
        for k, v in pairs(Components.HorseBedrolls) do
            if value == v.hashid then
                bedrollsHash = v.hash
            end
        end
        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
        local ped = PlayerPedId()
        local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
            if mount ~= nil then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(bedrollsHash), true, true, true) 
                TriggerServerEvent('rsg-horses:server:SaveBedrolls', bedrollsHash)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
            end
        end)
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle tails compontent
RegisterNetEvent('rsg-horses:client:setTails',function(category, value)
    if category == 'tails' then
        for k, v in pairs(Components.HorseTails) do
            if value == v.hashid then
                tailsHash = v.hash
            end
        end
        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
        local ped = PlayerPedId()
        local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
            if mount ~= nil then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(tailsHash), true, true, true) 
                TriggerServerEvent('rsg-horses:server:SaveTails', tailsHash)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
            end
        end)
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle manes compontent
RegisterNetEvent('rsg-horses:client:setManes',function(category, value)
    if category == 'manes' then
        for k, v in pairs(Components.HorseManes) do
            if value == v.hashid then
                manesHash = v.hash
            end
        end
        RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
        local ped = PlayerPedId()
        local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
            if mount ~= nil then
                Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(manesHash), true, true, true) 
                TriggerServerEvent('rsg-horses:server:SaveManes', manesHash)
            else
                RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
            end
        end)
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle masks compontent
RegisterNetEvent('rsg-horses:client:setMasks',function(category, value)
    if category == 'masks' then
        if value == 0 then
            RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
            local ped = PlayerPedId()
            local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
                if mount ~= nil then
                    Citizen.InvokeNative(0xD710A5007C2AC539, mount, 0xD3500E5D, 0)
                    Citizen.InvokeNative(0xCC8CA3E88256E58F, mount, 0, 1, 1, 1, 0)
                    TriggerServerEvent('rsg-horses:server:SaveMasks', 0)
                else
                    RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
                end
            end)
        else
            for k, v in pairs(Components.HorseMasks) do
                if value == v.hashid then
                    masksHash = v.hash
                end
            end
            RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
            local ped = PlayerPedId()
            local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
                if mount ~= nil then
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(masksHash), true, true, true) 
                    TriggerServerEvent('rsg-horses:server:SaveMasks', masksHash)
                else
                    RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
                end
            end)
        end
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

-- handle mustaches compontent
RegisterNetEvent('rsg-horses:client:setMustaches',function(category, value)
    if category == 'mustaches' then
        if value == 0 then
            RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
            local ped = PlayerPedId()
            local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
                if mount ~= nil then
                    Citizen.InvokeNative(0xD710A5007C2AC539, mount, 0x30DEFDDF, 0)
                    Citizen.InvokeNative(0xCC8CA3E88256E58F, mount, 0, 1, 1, 1, 0)
                    TriggerServerEvent('rsg-horses:server:SaveMustaches', 0)
                else
                    RSGCore.Functions.Notify(Lang:t('error.no_horse_found'), 'error')
                end
            end)
        else
            for k, v in pairs(Components.HorseMustaches) do
                if value == v.hashid then
                    mustachesHash = v.hash
                end
            end
            RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data, newnames)
            local ped = PlayerPedId()
            local mount = Citizen.InvokeNative(0x4C8B59171957BCF7, ped)
                if mount ~= nil then
                    Citizen.InvokeNative(0xD3A7B003ED343FD9, mount, tonumber(mustachesHash), true, true, true) 
                    TriggerServerEvent('rsg-horses:server:SaveMustaches', mustachesHash)
                else
                    RSGCore.Functions.Notify('No Horse Found', 'error')
                end
            end)
        end
    else
        print(Lang:t('error.something_went_wrong'))
    end
end)

----------------------------------------------------------------------------------------------------

RegisterNetEvent('rsg-horses:closeMenu', function()
    Wait(1000)
    DestroyAllCams(true)
end)

RegisterNetEvent('rsg-horses:closeMenu', function()
    exports['rsg-menu']:closeMenu()
end)

-- move horse to player
function moveHorseToPlayer()
    Citizen.CreateThread(function()
        --Citizen.InvokeNative(0x6A071245EB0D1882, horsePed, PlayerPedId(), -1, 5.0, 15.0, 0, 0)
        Citizen.InvokeNative(0x6A071245EB0D1882, horsePed, PlayerPedId(), -1, 7.2, 2.0, 0, 0)
        while horseSpawned == true do
            local coords = GetEntityCoords(PlayerPedId())
            local horseCoords = GetEntityCoords(horsePed)
            local distance = #(coords - horseCoords)
            if (distance < 7.0) then
                ClearPedTasks(horsePed, true, true)
                horseSpawned = false
            else
                HorseCalled = false
            end
            Wait(1000)
        end
    end)
end

function setPedDefaultOutfit(model)
    return Citizen.InvokeNative(0x283978A15512B2FE, model, true)
end

function getControlOfEntity(entity)
    NetworkRequestControlOfEntity(entity)
    SetEntityAsMissionEntity(entity, true, true)
    local timeout = 2000

    while timeout > 0 and NetworkHasControlOfEntity(entity) == nil do
        Wait(100)
        timeout = timeout - 100
    end
    return NetworkHasControlOfEntity(entity)
end

Citizen.CreateThread(function()
    while true do
        if (timeout) then
            if (timeoutTimer == 0) then
                timeout = false
            end
            timeoutTimer = timeoutTimer - 1
            Wait(1000)
        end
        Wait(0)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if (resource == GetCurrentResourceName()) then
        for k,v in pairs(entities) do
            DeletePed(v)
            SetEntityAsNoLongerNeeded(v)
        end
        for k,v in pairs(npcs) do
            DeletePed(v)
            SetEntityAsNoLongerNeeded(v)
        end
        if (horsePed ~= 0) then
            DeletePed(horsePed)
            SetEntityAsNoLongerNeeded(horsePed)
        end
    end
end)

CreateThread(function()
    for key,value in pairs(Config.ModelSpawns) do    
        local StablesBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, value.coords)
        SetBlipSprite(StablesBlip, GetHashKey(Config.Blip.blipSprite), true)
        SetBlipScale(StablesBlip, Config.Blip.blipScale)
        Citizen.InvokeNative(0x9CB1A1623062F402, StablesBlip, Config.Blip.blipName)
    end
end)

local HorseId = nil

RegisterNetEvent('rsg-horses:client:SpawnHorse', function(data)
    HorseId = data.player.id
    TriggerServerEvent("rsg-horses:server:SetHoresActive", data.player.id)
    RSGCore.Functions.Notify(Lang:t('success.horse_active'), 'success', 7500)
end)

-- flee horse
local function Flee()
    TaskAnimalFlee(horsePed, PlayerPedId(), -1)
    Wait(10000)
    DeleteEntity(horsePed)
    horsePed = 0
    HorseCalled = false
end

RegisterNetEvent("rsg-horses:client:storehorse", function(data)
    if (horsePed ~= 0) then
        TriggerServerEvent("rsg-horses:server:SetHoresUnActive", HorseId)
        RSGCore.Functions.Notify(Lang:t('success.storing_horse'), 'success', 7500)
        Flee()
        HorseCalled = false
    end
end)

RegisterNetEvent("rsg-horses:client:tradehorse", function(data)
    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data,newnames)
        if (horsePed ~= 0) then
            TradeHorse()
            Flee()
            HorseCalled = false
        else
            RSGCore.Functions.Notify(Lang:t('error.no_horse_out'), 'error', 7500)
        end
    end)
end)

RegisterNetEvent('rsg-horses:client:menu', function()
    local GetHorse = {
        {
            header = Lang:t('menu.my_horses'),
            isMenuHeader = true,
            icon = "fa-solid fa-circle-user",
        },
    }
    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetHorse', function(cb)
        for _, v in pairs(cb) do
            GetHorse[#GetHorse + 1] = {
                header = v.name,
                txt = Lang:t('menu.my_horse_gender')..v.gender..Lang:t('menu.my_horse_xp')..v.horsexp..Lang:t('menu.my_horse_active')..v.active,
                icon = "fa-solid fa-circle-user",
                params = {
                    event = "rsg-horses:client:SpawnHorse",
                    args = {
                        player = v,
                        active = 1
                    }
                }
            }
        end
        exports['rsg-menu']:openMenu(GetHorse)
    end)
end)

RegisterNetEvent('rsg-horses:client:MenuDel', function()
    local GetHorse = {
        {
            header = Lang:t('menu.sell_horses'),
            isMenuHeader = true,
            icon = "fa-solid fa-circle-user",
        },
    }
    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetHorse', function(cb)
        for _, v in pairs(cb) do
            GetHorse[#GetHorse + 1] = {
                header = v.name,
                txt = "Sell you horse",
                icon = "fa-solid fa-circle-user",
                params = {
                    event = "rsg-horses:client:MenuDelC",
                    args = {}
                }
            }
        end
        exports['rsg-menu']:openMenu(GetHorse)
    end)
end)


RegisterNetEvent('rsg-horses:client:MenuDelC', function(data)
    local GetHorse = {
        {
            header = "| Confirm Sell Horses |",
            isMenuHeader = true,
            icon = "fa-solid fa-circle-user",
        },
    }
    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetHorse', function(cb)
        for _, v in pairs(cb) do
            GetHorse[#GetHorse + 1] = {
                header = v.name,
                txt = Lang:t('menu.sell_warning'),
                icon = "fa-solid fa-circle-user",
                params = {
                    event = "rsg-horses:client:DeleteHorse",
                    args = {
                        player = v,
                        active = 1
                    }
                }
            }
        end
        exports['rsg-menu']:openMenu(GetHorse)
    end)
end)

RegisterNetEvent('rsg-horses:client:DeleteHorse', function(data)
    RSGCore.Functions.Notify(Lang:t('success.horse_sold'), 'success', 7500)
    TriggerServerEvent("rsg-horses:server:DelHores", data.player.id)
end)

-------------------------------------------------------------------------------

-- call / flee horse
CreateThread(function()
    while true do
        Wait(1)
        if Citizen.InvokeNative(0x91AEF906BCA88877, 0, RSGCore.Shared.Keybinds['H']) then -- call horse
            local coords = GetEntityCoords(PlayerPedId())
            local horseCoords = GetEntityCoords(horsePed)
            local distance = #(coords - horseCoords)

            if not HorseCalled and (distance > 100.0) then
                SpawnHorse()
                Wait(3000) -- Spam protect
            else
                moveHorseToPlayer()
            end
        end

        if Citizen.InvokeNative(0x91AEF906BCA88877, 0, RSGCore.Shared.Keybinds['HorseCommandFlee']) then -- flee horse
            if horseSpawned ~= 0 then
                Flee()
            end
        end
    end
end)

-------------------------------------------------------------------------------

-- open inventory by key
CreateThread(function()
    while true do
        Wait(1)

        local pcoords = GetEntityCoords(PlayerPedId())
        local hcoords = GetEntityCoords(horsePed)

        if #(pcoords - hcoords) <= 1.7 and Citizen.InvokeNative(0x580417101DDB492F, 0, Config.HorseInvKey) then
            TriggerEvent('rsg-horses:client:inventoryHorse')
        end
    end
end)

-- horse inventory
RegisterNetEvent('rsg-horses:client:inventoryHorse', function()
    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data)
        if horsePed == 0 then
            RSGCore.Functions.Notify(Lang:t('error.no_horse_out'), 'error', 7500)
            return
        end

        local horsestash = data.name..' '..data.horseid
        
        if horsexp <= 99 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level1InvWeight, slots = Config.Level1InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp >= 100 and horsexp <= 199 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level2InvWeight, slots = Config.Level2InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp >= 200 and horsexp <= 299 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level3InvWeight, slots = Config.Level3InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp >= 300 and horsexp <= 399 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level4InvWeight, slots = Config.Level4InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp >= 400 and horsexp <= 499 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level5InvWeight, slots = Config.Level5InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp >= 500 and horsexp <= 999 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level6InvWeight, slots = Config.Level6InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp >= 1000 and horsexp <= 1999 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level7InvWeight, slots = Config.Level7InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp >= 2000 and horsexp <= 2999 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level8InvWeight, slots = Config.Level8InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp >= 3000 and horsexp <= 3999 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level9InvWeight, slots = Config.Level9InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        elseif horsexp > 4000 then
            TriggerServerEvent("inventory:server:OpenInventory", "stash", horsestash, { maxweight = Config.Level10InvWeight, slots = Config.Level10InvSlots, })
            TriggerEvent("inventory:client:SetCurrentStash", horsestash)
        end
    end)
end)

-------------------------------------------------------------------------------

-- player equip horse lantern
RegisterNetEvent('rsg-horses:client:equipHorseLantern')
AddEventHandler('rsg-horses:client:equipHorseLantern', function()
    local hasItem = RSGCore.Functions.HasItem('horselantern', 1)

    if not hasItem then
        RSGCore.Functions.Notify(Lang:t('error.no_lantern'), 'error')
        return
    end

    local pcoords = GetEntityCoords(PlayerPedId())
    local hcoords = GetEntityCoords(horsePed)
    local distance = #(pcoords - hcoords)

    if distance > 2.0 then
        RSGCore.Functions.Notify(Lang:t('error.need_to_be_closer'), 'error')
        return
    end

    if lanternUsed then
        lanternUsed = false
        Wait(5000)
    end

    if lanternequiped == false then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, 0x635E387C, true, true, true)

        lanternequiped = true
        lanternUsed = true

        RSGCore.Functions.Notify(Lang:t('primary.lantern_equiped'), 'horse', 3000)
        return
    end

    if lanternequiped == true then
        Citizen.InvokeNative(0xD710A5007C2AC539, horsePed, 0x1530BE1C, 0)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, horsePed, 0, 1, 1, 1, 0)

        lanternequiped = false
        lanternUsed = true

        RSGCore.Functions.Notify(Lang:t('primary.lantern_removed'), 'horse', 3000)
        return
    end
end)

-------------------------------------------------------------------------------

-- player equip horse holster
RegisterNetEvent('rsg-horses:client:equipHorseHolster')
AddEventHandler('rsg-horses:client:equipHorseHolster', function()
    local hasItem = RSGCore.Functions.HasItem('horseholster', 1)
    if not hasItem then
        RSGCore.Functions.Notify(Lang:t('error.no_holster'), 'error')
        return
    end

    local pcoords = GetEntityCoords(PlayerPedId())
    local hcoords = GetEntityCoords(horsePed)
    local distance = #(pcoords - hcoords)

    if distance > 2.0 then
        RSGCore.Functions.Notify(Lang:t('error.need_to_be_closer'), 'error')
        return
    end

    if holsterUsed then
        holsterUsed = false
        Wait(5000)
    end

    if holsterequiped == false then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, horsePed, 0xF772CED6, true, true, true)

        holsterequiped = true
        holsterUsed = true

        RSGCore.Functions.Notify(Lang:t('primary.holster_equiped'), 'horse', 3000)
        return
    end

    if holsterequiped == true then
        Citizen.InvokeNative(0xD710A5007C2AC539, horsePed, -1408210128, 0)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, horsePed, 0, 1, 1, 1, 0)

        holsterequiped = false
        holsterUsed = true

        RSGCore.Functions.Notify(Lang:t('primary.holster_removed'), 'horse', 3000)
        return
    end
end)

-------------------------------------------------------------------------------

-- player feed horse
RegisterNetEvent('rsg-horses:client:playerfeedhorse')
AddEventHandler('rsg-horses:client:playerfeedhorse', function(itemName)
    local pcoords = GetEntityCoords(PlayerPedId())
    local hcoords = GetEntityCoords(horsePed)

    if #(pcoords - hcoords) > 2.0 then
        RSGCore.Functions.Notify(Lang:t('error.need_to_be_closer'), 'error')
        return
    end

    if itemName == 'carrot' then
        Citizen.InvokeNative(0xCD181A959CFDD7F4, PlayerPedId(), horsePed, -224471938, 0, 0) -- TaskAnimalInteraction

        Wait(5000)

        local horseHealth = Citizen.InvokeNative(0x36731AC041289BB1, horsePed, 0) -- GetAttributeCoreValue (Health)
        local newHealth = horseHealth + Config.FeedCarrotHealth
        local horseStamina = Citizen.InvokeNative(0x36731AC041289BB1, horsePed, 1) -- GetAttributeCoreValue (Stamina)
        local newStamina = horseStamina + Config.FeedCarrotStamina

        if Config.Debug then
            print(horseStamina)
            print(Config.FeedCarrotStamina)
        end

        Citizen.InvokeNative(0xC6258F41D86676E0, horsePed, 0, newHealth) -- SetAttributeCoreValue (Health)
        Citizen.InvokeNative(0xC6258F41D86676E0, horsePed, 1, newStamina) -- SetAttributeCoreValue (Stamina)

        PlaySoundFrontend("Core_Fill_Up", "Consumption_Sounds", true, 0)
    end

    if itemName == 'sugarcube' then
        Citizen.InvokeNative(0xCD181A959CFDD7F4, PlayerPedId(), horsePed, -224471938, 0, 0) -- TaskAnimalInteraction

        Wait(5000)

        local horseHealth = Citizen.InvokeNative(0x36731AC041289BB1, horsePed, 0) -- GetAttributeCoreValue (Health)
        local newHealth = horseHealth + Config.FeedSugarCubeHealth
        local horseStamina = Citizen.InvokeNative(0x36731AC041289BB1, horsePed, 1) -- GetAttributeCoreValue (Stamina)
        local newStamina = horseStamina + Config.FeedSugarCubeStamina

        Citizen.InvokeNative(0xC6258F41D86676E0, horsePed, 0, newHealth) -- SetAttributeCoreValue (Health)
        Citizen.InvokeNative(0xC6258F41D86676E0, horsePed, 1, newStamina) -- SetAttributeCoreValue (Stamina)

        PlaySoundFrontend("Core_Fill_Up", "Consumption_Sounds", true, 0)
    end
end)

-- player brush horse
RegisterNetEvent('rsg-horses:client:playerbrushhorse')
AddEventHandler('rsg-horses:client:playerbrushhorse', function(itemName)
    local pcoords = GetEntityCoords(PlayerPedId())
    local hcoords = GetEntityCoords(horsePed)

    if #(pcoords - hcoords) > 2.0 then
        RSGCore.Functions.Notify(Lang:t('error.need_to_be_closer'), 'error')
        return
    end

    Citizen.InvokeNative(0xCD181A959CFDD7F4, PlayerPedId(), horsePed, `INTERACTION_BRUSH`, 0, 0)

    Wait(8000)

    Citizen.InvokeNative(0xE3144B932DFDFF65, horsePed, 0.0, -1, 1, 1)
    ClearPedEnvDirt(horsePed)
    ClearPedDamageDecalByZone(horsePed, 10, "ALL")
    ClearPedBloodDamage(horsePed)
    Citizen.InvokeNative(0xD8544F6260F5F01E, horsePed, 10)

    PlaySoundFrontend("Core_Fill_Up", "Consumption_Sounds", true, 0)
end)

-------------------------------------------------------------------------------
