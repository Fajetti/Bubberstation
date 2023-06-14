/datum/computer_file/program/minesweeper
	filename = "minesweeper"
	filedesc = "Nanotrasen Micro Arcade: Minesweeper"
	program_icon_state = "arcade"
	extended_desc = "A port of the classic game 'Minesweeper', redesigned to run on tablets."
	requires_ntnet = FALSE
	size = 6
	tgui_id = "NtosMinesweeper"
	program_icon = "gamepad"

	var/datum/minesweeper/board

/datum/computer_file/program/minesweeper/New(obj/item/modular_computer/comp)
	. = ..()
	board = new /datum/minesweeper()
	board.emaggable = FALSE
	board.host = comp

/datum/computer_file/program/minesweeper/Destroy()
	board.host = null
	QDEL_NULL(board)
	. = ..()

/datum/computer_file/program/minesweeper/ui_assets(mob/user)
	return list(
		get_asset_datum(/datum/asset/simple/minesweeper),
	)

/datum/computer_file/program/minesweeper/ui_data(mob/user)
	var/list/data = list()

	data["board_data"] = board.board_data
	data["game_status"] = board.game_status
	data["difficulty"] = board.diff_text(board.difficulty)
	data["current_difficulty"] = board.current_difficulty
	data["emagged"] = FALSE
	data["flag_mode"] = board.flag_mode
	data["tickets"] = board.ticket_count
	data["flags"] = board.flags
	data["current_mines"] = board.current_mines
	data["custom_height"] = board.custom_height
	data["custom_width"] = board.custom_width
	data["custom_mines"] = board.custom_mines
	var/display_time = (board.time_frozen ? board.time_frozen : REALTIMEOFDAY - board.starting_time) / 10
	data["time_string"] = board.starting_time ? "[add_leading(num2text(FLOOR(display_time / 60,1)), 2, "0")]:[add_leading(num2text(display_time % 60), 2, "0")]" : "00:00"

	return data

/datum/computer_file/program/minesweeper/ui_act(action, list/params, mob/user)
	if(..())
		return TRUE

	if(!board)
		return

	if(!board.host && computer)
		board.host = computer


	switch(action)
		if("PRG_do_tile")
			var/x = params["x"]
			var/y = params["y"]
			var/flagging = params["flag"]
			if(!x || !y)
				return

			return board.do_tile(x,y,flagging,user)

		if("PRG_new_game")
			board.play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
			return board.new_game()

		if("PRG_difficulty")
			var/diff = params["difficulty"]
			if(!diff)
				return
			board.play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
			return board.change_difficulty(diff)

		if("PRG_height")
			var/cin = params["height"]
			if(!cin)
				return
			return board.set_custom_height(cin)

		if("PRG_width")
			var/cin = params["width"]
			if(!cin)
				return
			cin = text2num(cin)
			if(cin < 5 || cin > 30)
				cin = clamp(cin, 5, 30)
			board.custom_width = cin
			board.custom_mines = min(board.custom_mines, FLOOR(board.custom_width*board.custom_height/2,1))
			board.difficulty = MINESWEEPER_CUSTOM
			return TRUE

		if("PRG_mines")
			var/cin = params["mines"]
			if(!cin)
				return
			cin = text2num(cin)
			if(cin < 5 || cin > FLOOR(board.custom_width*board.custom_height/2,1))
				cin = clamp(cin, 5, FLOOR(board.custom_width*board.custom_height/2,1))
			board.custom_mines = cin
			board.difficulty = MINESWEEPER_CUSTOM
			return TRUE

		if("PRG_toggle_flag")
			board.play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
			board.flag_mode = !board.flag_mode
			return TRUE


/datum/minesweeper
	var/ticket_count = 0
	var/flag_mode = FALSE
	var/flags = 0
	var/current_mines = 10
	var/difficulty = MINESWEEPER_BEGINNER
	var/value = MINESWEEPER_BEGINNER
	var/current_difficulty = "Beginner"

	var/starting_time = 0
	var/time_frozen = 0

	var/custom_height = 10
	var/custom_width = 10
	var/custom_mines = 10

	var/game_status = MINESWEEPER_IDLE

	var/board_data[31][18]
	var/mine_spots = list()
	var/height = 10
	var/width = 10
	var/mines = 10

	var/tiles_left = 100

	var/obj/host
	var/emaggable = FALSE
	COOLDOWN_DECLARE(new_game_cd)

/datum/minesweeper/proc/play_snd(sound)
	/*if(istype(host, /obj/item/modular_computer))
		var/obj/item/modular_computer/comp = host
		playsound(get_turf(), sound, 50, 0)
	else*/
	playsound(get_turf(host), sound, 50, 0, extrarange = -3, falloff_exponent = 10)

/datum/minesweeper/proc/vis_msg(msg, local_msg)
	if(istype(host, /obj/item/modular_computer))
		var/obj/item/modular_computer/comp = host
		comp.visible_message(msg)
	else
		host.visible_message(msg, local_msg)

/datum/minesweeper/proc/set_custom_height(cin)
	cin = text2num(cin)
	if(cin < 5 || cin > 17)
		cin = clamp(cin, 5, 17)
	custom_height = cin
	custom_mines = min(custom_mines, FLOOR(custom_width*custom_height/2,1))
	difficulty = MINESWEEPER_CUSTOM
	return TRUE

/datum/minesweeper/proc/change_difficulty(diff)
	difficulty = diff
	return TRUE

/datum/minesweeper/proc/new_game()
	if(!COOLDOWN_FINISHED(src, new_game_cd))
		host.say("Please wait [COOLDOWN_TIMELEFT(src, new_game_cd)/10] more seconds before starting a new game.")
		return
	COOLDOWN_START(src, new_game_cd, 1.5 SECONDS)
	generate_new_board(difficulty)
	current_difficulty = diff_text(difficulty)
	current_mines = mines
	flags = 0
	starting_time = 0
	return TRUE

/datum/minesweeper/proc/do_tile(x,y,flagging,mob/user)
	if(game_status)
		return

	if(board_data[x][y] != "minesweeper_hidden.png" && !flag_mode && !flagging)
		return

	if(flag_mode || flagging)
		if(board_data[x][y] == "minesweeper_hidden.png")
			board_data[x][y] = "minesweeper_flag.png"
			flags++
			play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
		else if(board_data[x][y] == "minesweeper_flag.png")
			board_data[x][y] = "minesweeper_hidden.png"
			flags--
			play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')
		else
			return
		return TRUE

	play_snd('modular_zubbers/sound/arcade/minesweeper_boardpress.ogg')

	if(current_difficulty != diff_text(difficulty))
		generate_new_board(difficulty)
		x = min(x,width)
		y = min(y,height)
		current_difficulty = diff_text(difficulty)
		current_mines = mines
		flags = 0
		time_frozen = 0

	if(width * height == tiles_left)
		current_mines = mines
		if(!is_blank_tile_start(x,y))
			move_bombs(x,y) // The first selected tile will always be a blank one.
		time_frozen = 0
		starting_time = REALTIMEOFDAY

	if(difficulty == MINESWEEPER_CUSTOM)
		switch(mines/(height*width))
			if(0.1 to 0.14999)
				value = 1
			if(0.14999 to 0.19999)
				if(height >= 13 && width >= 13)
					value = 4
				else
					value = 1
			if(0.19999 to 0.29999)
				if(height >= 13 && width >= 25)
					value = 20
				else
					value = 1
			if(0.29999 to 1)
				if(height >= 13 && width >= 25)
					value = 25
				else
					value = 2
			else
				value = 0
	else
		switch(difficulty)
			if(MINESWEEPER_BEGINNER)
				value = 1
			if(MINESWEEPER_INTERMEDIATE)
				value = 4
			if(MINESWEEPER_EXPERT)
				value = 20

	var/result = select_square(x,y)
	game_status = result
	if(result == MINESWEEPER_VICTORY)
		play_snd('modular_zubbers/sound/arcade/minesweeper_win.ogg')
		host.say("You cleared the board of all mines! Congratulations!")
		ticket_count += value

	//if(result == MINESWEEPER_DEAD && emaggable && (host.obj_flags & EMAGGED))
		// One crossed wire, one wayward pinch of potassium chlorate, ONE ERRANT TWITCH
		// AND
		//KABLOOEY() Not... yet

	if(result)
		time_frozen = REALTIMEOFDAY - starting_time

	return TRUE

/datum/minesweeper/proc/generate_new_board(diff)
	board_data = new /list(31,18) // Fresh board
	mine_spots = list()

	switch(diff)
		if(MINESWEEPER_BEGINNER) // 10x10, 10 mines
			width = 10
			height = 10
			mines = 10
		if(MINESWEEPER_INTERMEDIATE) // 17x17, 40 mines
			width = 17
			height = 17
			mines = 40
		if(MINESWEEPER_EXPERT) // 30x16, 99 mines
			width = 30
			height = 16
			mines = 99
		if(MINESWEEPER_CUSTOM)
			width = custom_width
			height = custom_height
			mines = custom_mines

	tiles_left = width * height

	mines = min(FLOOR(tiles_left/2,1), mines) // Crash protection

	for(var/i=1, i<mines+1, i++) // Set up mines
		var/mine_spot = list(rand(0,width-1),rand(0,height-1))
		while(find_in_mines(mine_spot)) // There's already a mine here! Choose another spot
			mine_spot = list(rand(0,width-1),rand(0,height-1))
		mine_spots += list(mine_spot)

	for(var/y=1, y<height+1, y++) // Set all squares to be hidden
		for(var/x=1, x<width+1, x++)
			board_data[x][y] = "minesweeper_hidden.png"

	game_status = MINESWEEPER_CONTINUE

/datum/minesweeper/proc/select_square(x,y)
	if(find_in_mines(list(x-1,y-1)))
		board_data[x][y] = "minesweeper_minehit.png"
		for(var/list/mine in mine_spots)
			if(mine[1] == x-1 && mine[2] == y-1)
				continue
			board_data[mine[1]+1][mine[2]+1] = "minesweeper_mine.png"
		switch(rand(1,3))
			if(1)
				play_snd('modular_zubbers/sound/arcade/minesweeper_explosion1.ogg')
			if(2)
				play_snd('modular_zubbers/sound/arcade/minesweeper_explosion2.ogg')
			if(3)
				play_snd('modular_zubbers/sound/arcade/minesweeper_explosion3.ogg')
		return MINESWEEPER_DEAD

	tiles_left--

	var/mine_count = 0
	for(var/scanx=-1, scanx<2, scanx++) // -1, 0, 1
		for(var/scany=-1, scany<2, scany++)
			if(scanx+x < 1 || scany+y < 1)
				continue
			if(scanx == 0 && scany == 0) // We know we aren't a mine
				continue
			if(board_data[scanx+x][scany+y] != "minesweeper_hidden.png" && board_data[scanx+x][scany+y] != "minesweeper_flag.png")
				continue
			if(find_in_mines(list(scanx+x-1,scany+y-1)))
				mine_count++

	if(mine_count == FALSE) // There are no mines around me! Select every square adjacent!
		board_data[x][y] = "minesweeper_empty.png"
		for(var/scanx=-1, scanx<2, scanx++) // -1, 0, 1
			for(var/scany=-1, scany<2, scany++)
				if(scanx+x < 1 || scany+y < 1)
					continue
				if(scanx == 0 && scany == 0)
					continue
				if(board_data[scanx+x][scany+y] != "minesweeper_hidden.png")
					continue
				select_square(scanx+x,scany+y)
	else
		board_data[x][y] = "minesweeper_[mine_count].png"

	return tiles_left <= mines ? MINESWEEPER_VICTORY : MINESWEEPER_CONTINUE

/datum/minesweeper/proc/diff_text(diff)
	return list("Beginner", "Intermediate", "Expert", "Custom")[diff]

/datum/minesweeper/proc/find_in_mines(list/coord)
	var/order = 0
	for(var/list/L in mine_spots)
		order++
		if(coord[1] == L[1] && coord[2] == L[2])
			return order
	return FALSE

/datum/minesweeper/proc/is_blank_tile_start(x,y)
	for(var/scanx=-1, scanx<2, scanx++) // -1, 0, 1
		for(var/scany=-1, scany<2, scany++)
			if(scanx+x < 1 || scany+y < 1)
				continue
			if(find_in_mines(list(scanx+x-1,scany+y-1)))
				return FALSE
	return TRUE

/datum/minesweeper/proc/move_bombs(x,y)
	for(var/scanx=-1, scanx<2, scanx++) // -1, 0, 1
		for(var/scany=-1, scany<2, scany++)
			if(scanx+x < 1 || scany+y < 1)
				continue
			var/mine_index = find_in_mines(list(scanx+x-1,scany+y-1))
			if(mine_index)
				var/mine_spot = list(rand(0,width-1),rand(0,height-1))
				while(find_in_mines(mine_spot) || is_surrounding(x,y,mine_spot)) // There's already a mine here/surrounding! Choose another spot
					mine_spot = list(rand(0,width-1),rand(0,height-1))
				mine_spots[mine_index] = mine_spot

/datum/minesweeper/proc/is_surrounding(x,y,list/coord)
	for(var/scanx=-1, scanx<2, scanx++) // -1, 0, 1
		for(var/scany=-1, scany<2, scany++)
			if(scanx+x < 1 || scany+y < 1)
				continue
			var/list/C = list(scanx+x-1,scany+y-1)
			if(coord[1] == C[1] && coord[2] == C[2])
				return TRUE
	return FALSE

/datum/minesweeper/proc/KABLOOEY()
	explosion(get_turf(host),0,1,rand(1,3),rand(1,5))

#undef MINESWEEPER_BEGINNER
#undef MINESWEEPER_INTERMEDIATE
#undef MINESWEEPER_EXPERT
#undef MINESWEEPER_CUSTOM

#undef MINESWEEPER_CONTINUE
#undef MINESWEEPER_DEAD
#undef MINESWEEPER_VICTORY
#undef MINESWEEPER_IDLE
