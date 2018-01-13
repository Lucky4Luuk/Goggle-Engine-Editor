-- Configuration
function love.conf(t)
	t.title = "Goggle Engine" -- The title of the window the game is in (string)
	t.version = "0.11.0"            -- The LÖVE version this game was made for (string)
	t.window.width = 768           -- we want our game to be long and thin.
	t.window.height = 432
	t.window.resizable = true

	t.window.vsync = false

	-- For Windows debugging
	t.console = true
end
