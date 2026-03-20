getgenv().Solix = {
    ["Auto Farm"] = true,
    ["Stat Allocation"] = "Auto (weapon-based)",
    Reroll = {
        ["Only Roll If have Title Lucky"] = { 
            ["Enable"] = true, 
            ["Title"] = "Destiny Marked" },
        Clan = { 
            ["Enable"] = true, 
            ["Keep"] = {"Monarch"} },
        Race = { 
            ["Enable"] = true, 
            ["Keep"] = {"Oni","Kitsune","Leviathan","Slime","Servant","Sunborn","Galevorn","Swordblessed"} },
        Trait = { 
            ["Enable"] = true, 
            ["Keep"] = {"Overload","Cataclysm","Singularity","Celestial","Godspeed","Sovereign","Infinity","Malevolent"} },
    },
    ["Task Do After Max Level"] = { 
        ["Auto Kill Saber Until Full Title"] = true, 
        ["Farm Drops"] = true },
    Performance = { 
        ["FPS Lock"] = 30, 
        ["Low CPU"] = false }
}
script_key="ameuzvwjIzGEkkqbAKiMTnrxhfgOGJYD";
loadstring(game:HttpGet("https://raw.githubusercontent.com/meobeo8/a/a/a"))()
