_G.FishItConfig = _G.FishItConfig or {
    ["Fishing"] = {
        ["Auto Perfect"] = true,
        ["Random Result"] = false,
        ["Auto Favorite"] = true,
        ["Auto Unfavorite"] = false,
        ["Fish Name"] = {
            "Sacred Guardian Squid",
            {Name = "Ruby", Variant = "Gemstone"}
        },
        ["Auto Accept Trade"] = true,
        ["Auto Friend Request"] = false,
    },
    ["Auto Trade"] = {
        ["Enabled"] = true,
        ["Whitelist Username"] = {"0xC1P4"},
        ["Category Fish"] = {
            "Secret"
        },
        ["Fish Name"] = {
            "Sacred Guardian Squid",
            {Name = "Ruby", Variant = "Gemstone"}
        },
        ["Item Name"] = {"Evolved Enchant Stone"},
    },
    ["Selling"] = {
        ["Auto Sell"] = true,
        ["Auto Sell Threshold"] = "Mythic",
        ["Auto Sell Every"] = 40,
    },
    ["Doing Quest"] = {
        ["Auto Ghostfinn Rod"] = true,
        ["Auto Element Rod"] = false,
        ["Auto Element Rod 2"] = true,
        ["Auto Diamond Rod"] = false,
        ["Unlock Ancient Ruin"] = false,
        ["Allowed Sacrifice"] = {"Ghost Shark", "Cryoshade Glider", "Panther Eel", "Queen Crab", "King Crab", "Blob Shark", "Ghost Shark", "Giant Squid", "Mosasaur Shark", "Panther Eel", "Bone Whale", "Viridis Lurker", "Bone Whale", "King Jelly", "Elshark Gran Maja", "Depthseeker Ray", "Kraken", "Mossasaur Shark", "Gladiator Shark"},
        ["FARM_LOC_SECRET_SACRIFICE"] = "Treasure Room",
        ["Minimum Rod"] = "Astral Rod",
    },
    ["WebHook"] = {
        ["Category"] = {
            "Secret",
            {Name = "Ruby", Variant = "Gemstone"},
        ["Item Name"] = {"Evolved Enchant Stone"},
        ["Link Webhook"] = "https://discord.com/api/webhooks/1419857298951639160/HslxxzTZiGKyfpVesZQpaYZW37jrZS4quH0XX9yHbORB9WkeBLeb75wVFIEktzSUzuQd",
        ["Link Webhook Quest Complete"] = "https://discord.com/api/webhooks/1480049444891398329/jmwMBVo76ZLowVNQW-R5WeN03iWlJ_OkFBGxHJhjtYJlW7f0BOdHE0tHN3YP-H6Xswjo",
    },
    ["Weather"] = {
        ["Auto Buying"] = true,
        ["Minimum Rod"] = "Ghostfinn Rod",
        ["Weather List"] = {
            "Wind", 
            "Storm", 
            "Cloudy"
        },
    },
    ["Potions"] = {
        ["Auto Use"] = true,
        ["Minimum Rod"] = "Astral Rod",
    },
    ["Totems"] = {
        ["Auto Use"] = true,
        ["Minimum Rod"] = "Ghostfinn Rod",
        ["Buy List"] = {
            ["Mutation Totem"] = 20
        },
    },
    ["Enchant"] = {
        ["Auto Enchant"] = true,
        ["Roll Enchant"] = false,
        ["Evolved Roll Enchant"] = false,
        ["Enchant List"] = {
            "Cursed",
            "Reeler I",
        },
        ["Second Enchant"] = true,
        ["Allowed Sacrifice"] = {""},
        ["Second Enchant List"] = {
            "Perfection",
            "Cursed",
            "Reeler I",
        },
        ["Minimum Rod"] = "Element Rod",
    },
    ["Bait List"] = {
        ["Auto Buying"] = true,
        ["Buy List"] = {"Midnight Bait", "Chroma Bait", "Corrupt Bait", "Aether Bait", "Singularity Bait"},
        ["Endgame"] = "Singularity Bait",
    },
    ["Rod List"] = {
        ["Auto Buying"] = true,
        ["Buy List"] = {"Grass Rod", "Midnight Rod", "Astral Rod", "Ares Rod"},
        ["Location Rods"] = {
            ["Fisherman Island"] = {"Starter Rod"},
            ["Kohana Volcano"] = {"Grass Rod", "Midnight Rod"},
            ["Tropical Grove"] = {"Astral Rod"},
            ["Kohana"] = {"Ares Rod"},
            ["Ancient Ruin"] = {"Element Rod", "Ghostfinn Rod"}
        },
        ["Endgame"] = "Element Rod",
    },
    ["ExtremeFpsBoost"] = true,
    ["UltimatePerformance"] = false,
    ["Disable3DRender"] = false,
    ["AutoRemovePlayer"] = true,
    ["AutoReconnect"] = false,
    ["HideGUI"] = false,
    ["EXIT_MAP_IF_DISCONNECT"] = false,
}

script_key="4A20F9BFF197F1ED593B7401400C54EA";

local s,r repeat s,r=pcall(function()return game:HttpGet("https://raw.githubusercontent.com/FnDXueyi/roblog/refs/heads/main/fishit-78c86024ea87c8eca577549807421962.lua")end)wait(1)until s;loadstring(r)()
