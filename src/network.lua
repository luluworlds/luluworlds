return {
	CTRL_KEEP_ALIVE = 0x00,
	CTRL_CONNECT = 0x01,
	CTRL_ACCEPT = 0x02,
	CTRL_CLOSE = 0x04,
	CTRL_TOKEN = 0x05,

	SYS_INFO = 1,
	SYS_MAP_CHANGE = 2,
	SYS_MAP_DATA = 3,
	SYS_SERVER_INFO = 4,
	SYS_CON_READY = 5,
	SYS_SNAP = 6,
	SYS_SNAP_EMPTY = 7,
	SYS_SNAP_SINGLE = 8,
	SYS_SNAP_SMALL = 9,

	SYS_ENTER_GAME = string.char(0x27),
	SYS_INPUT = string.char(0x29),
	SYS_INPUT_TIMING = 10,

	GAME_SV_CHAT = 3,
	GAME_READY_TO_ENTER = 8,
}