getgenv().Solix = {
    ["Auto Farm"] = true,
    ["Stat Allocation"] = "Auto (weapon-based)",
    Reroll = {
        ["Only Roll If have Title Lucky"] = { 
            ["Enable"] = true, 
            ["Title"] = "Destiny Marked" },
        Clan = { 
            ["Enable"] = true, 
            ["Keep"] = {"Monarch", "Eminence"} },
        Race = { 
            ["Enable"] = true, 
            ["Keep"] = {"Kitsune"} },
        Trait = { 
            ["Enable"] = true, 
            ["Keep"] = {"Overload","Cataclysm","Singularity","Celestial","Godspeed","Sovereign","Infinity","Malevolent"} },
    },
    ["Task Do After Max Level"] = { 
        ["Auto Kill Saber Until Full Title"] = true, 
        ["Farm Drops"] = true },
    Performance = { 
        ["FPS Lock"] = 10, 
        ["Low CPU"] = true}
}
script_key="";
loadstring(game:HttpGet("https://raw.githubusercontent.com/meobeo8/a/a/a"))()
