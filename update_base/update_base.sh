#!/bin/bash

script_directory="$(dirname "$0")"

# Устанавливаем путь к исполняемому файлу sqlite3 в зависимости от OS
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  # Windows
  sqlite="$script_directory/sqlite3.exe"
else
  # Linux или другие Unix-подобные системы
  sqlite=$(which sqlite3)
fi

# Создаем файл базы данных games.db в которой хранятся пути к играм и т.п.
database_file="../games.db"

# Создаем файл базы данных database.sqlite3 в которой хранится история и избранное
database_history="../database.sqlite3"

# Создаем таблицы в базе данных
# Если хотите или есть потребность, то удалите все строчки начинающиеся с PRAGMA.
{
  echo "PRAGMA page_size = 4096;
    PRAGMA auto_vacuum = FULL; 
    PRAGMA journal_mode = WAL;
    PRAGMA temp_store = MEMORY; 
    PRAGMA synchronous = OFF;"
  echo "BEGIN;"
  echo "CREATE TABLE IF NOT EXISTS tbl_game (
    gameid INTEGER PRIMARY KEY,
    game CHAR(50),
    suffix CHAR(5),
    zh_id INTEGER,
    en_id INTEGER,
    ko_id INTEGER,
    tw_id INTEGER,
    video_id INTEGER,
    class_type INTEGER,
    game_type INTEGER,
    hard INTEGER,
    timer CHAR(50)
  );"
  echo "CREATE TABLE IF NOT EXISTS tbl_en (
    en_id INTEGER PRIMARY KEY,
    en_title CHAR(50)
  );"
  echo "CREATE TABLE IF NOT EXISTS tbl_ko (
    ko_id INTEGER PRIMARY KEY,
    ko_title CHAR(50)
  );"
  echo "CREATE TABLE IF NOT EXISTS tbl_zh (
    zh_id INTEGER PRIMARY KEY,
    zh_title CHAR(50)
  );"
  echo "CREATE TABLE IF NOT EXISTS tbl_tw (
    tw_id INTEGER PRIMARY KEY,
    tw_title CHAR(50)
  );"
  echo "CREATE TABLE IF NOT EXISTS tbl_match (
    ID INTEGER PRIMARY KEY,
    zh_match CHAR(50)
  );"
  echo "CREATE TABLE IF NOT EXISTS tbl_path (
    path_id INTEGER PRIMARY KEY,
    path TEXT
  );"
  echo "CREATE TABLE IF NOT EXISTS tbl_video (
    video_id INTEGER,
    video TEXT,
    path_id INTEGER
  );"
  echo "CREATE TABLE IF NOT EXISTS tbl_total (
    ID INTEGER,
    total INTEGER,
    PRIMARY KEY(ID)
  );"
  echo "CREATE TABLE IF NOT EXISTS files (
    path CHAR(50),
    file_name CHAR(50),
    extension CHAR(5),
    class_type INTEGER,
    game_type INTEGER,
    gstl_cores INTEGER
  );"
  echo "COMMIT;"
} | "$sqlite" "$database_file"


# Создаем таблицы в базе данных database_history
{
  echo "PRAGMA page_size = 4096;
    PRAGMA auto_vacuum = FULL; 
    PRAGMA journal_mode = WAL;
    PRAGMA temp_store = MEMORY; 
    PRAGMA synchronous = OFF;"  
  echo "BEGIN;"
  echo "CREATE TABLE IF NOT EXISTS GameInfo (
    ID INTEGER PRIMARY KEY, 
    GameID INTEGER, 
    STATUS INTEGER
  );"
  echo "CREATE TABLE IF NOT EXISTS History (
    ID INTEGER PRIMARY KEY, 
    GameID INTEGER, 
    STATUS INTEGER
  );"
  echo "CREATE TABLE IF NOT EXISTS TempTable (
    ID INTEGER PRIMARY KEY,
    favorites_match CHAR(50),
    history_match CHAR(50),
    rom_path CHAR(50),
    sort_order INTEGER
  );"
  echo "COMMIT;"
} | "$sqlite" "$database_history"


echo "
	-- Подключение базы данных
	ATTACH DATABASE '$database_file' AS game_db;

	-- Удаление записей из таблицы GameInfo, где статус равен NULL или не равен 5
	DELETE FROM GameInfo
	WHERE STATUS IS NULL OR STATUS != 5;

	-- Вставка данных во временную таблицу TempTable, для избранного
	INSERT INTO TempTable (favorites_match, rom_path, sort_order)
	SELECT DISTINCT game_db.tbl_match.zh_match AS favorites_match, game_db.tbl_game.timer AS rom_path, GameInfo.ID as sort_order
	FROM game_db.tbl_match
	JOIN GameInfo ON GameInfo.GameID = game_db.tbl_match.ID
	JOIN game_db.tbl_game ON game_db.tbl_game.gameid = GameInfo.GameID;

	-- Вставка данных во временную таблицу TempTable, для истории
	INSERT INTO TempTable (history_match, rom_path, sort_order)
	SELECT DISTINCT game_db.tbl_match.zh_match AS history_match, game_db.tbl_game.timer AS rom_path, History.ID as sort_order
	FROM game_db.tbl_match
	JOIN History ON History.GameID = game_db.tbl_match.ID
	JOIN game_db.tbl_game ON game_db.tbl_game.gameid = History.GameID;
" | $sqlite "$database_history"



:<<COMMENT
В общем, тут идут строки для поиска ромов по папкам и т.п.
Они выглядит так: "class_type,game_type,core,extensions,path", который разделен запятой, где:
1. class_type - номер приставки в minigui (не помню как меню называется, там где 9 приставок на выбор, а после нажатия пишет "Class reading")
2. game_type - номер ядра из start_game.sh, которое используется для запуска.
3. core - название ядра, которое используется из start_game.sh (оно в целом ни на что не влияет в дальнейшем скрипте, просто для себя сделал)
4. extensions - расширения, которые "кушает" ядро. Можно брать отсюда "https://github.com/libretro/libretro-super/tree/master/dist/info" - 
   из строчки "supported_extensions", просто копируя.
5. path - путь к папке с играми той или иной приставки.
COMMENT
# Формируем массив из таблицы
#"class_type,game_type,core,extensions,path"
game_data=(
  [0]="0,0,fbalpha2012_libretro,iso|zip|7z,../cps/fbalpha2012"
  [1]="1,1,nestopia_libretro,nes|fds|unf|unif,../fc"
  [2]="5,5,genesisplusgx_libretro,mdx|md|smd|gen|bin|iso|sms|bms|gg|sg|68k|sgd|chd|m3u,../md/SegaGenesis"
  [3]="6,6,snes9x_libretro,smc|sfc|swc|fig|bs|st,../sfc"
  [4]="2,7,mgba_libretro,gb,../gb"
  [5]="3,7,mgba_libretro,gba,../gba"
  [6]="4,7,mgba_libretro,gbc,../gbc"
  [7]="9,8,mupen64plus_libretro,n64|v64|z64|ndd|bin|u1,../n64"
  [8]="4,9,pcsx_rearmed_libretro_default_v5,bin|img|mdf|pbp|toc|cbn|m3u|chd,../ps1"
  [9]="12,10,mednafen_pce_fast_libretro,pce|chd|toc|m3u,../pcengine"
  [10]="11,12,desmume2015_libretro,nds|ids|bin,../ds"
  [11]="0,18,mame2016_libretro,zip|chd|7z|cmd,../cps/mame2016"
  [12]="7,21,stella_libretro_other,a26|bin,../atari/atari2600"
  [13]="7,22,atari800_libretro_other,xfd|atr|cdm|cas|bin|a52|zip|atx|car|rom|com|xex,../atari/atari800"
  [14]="7,23,prosystem_libretro_other,a26|bin,../atari/atari7800"
  [15]="8,27,fuse_libretro,tzx|tap|z80|rzx|scl|trd|dsk|zip,../spec"
  [16]="5,29,picodrive_libretro.so,bin|gen|smd|md|32x|iso|chd|sms|gg|sg|sc|m3u|68k|sgd|pco,../md/Sega32X"
  [17]="10,31,yabause_libretro,bin|chd|iso|mds|zip|m3u,../saturn"
  [18]="13,33,flycast_libretro,chd|cdi|elf|bin|gdi|lst|zip|dat|7z|m3u,../dreamcast"
  [19]="14,34,scummvm_libretro,scummvm,../scummvm"
  [20]="15,35,dosbox_svn_libretro,exe|com|bat|conf|iso|dos,../dos"
  [21]="0,37,fbneo_libretro,zip|7z,../fbneo"
  [22]="17,38,squirreljme_libretro,jar|sqc|jam|jad|kjx,../j2me"
  [23]="19,39,4do_libretro,iso|bin|chd,../3do"
  [24]="18,15,scripts,gsts,../scripts"
)


# Формируем пакетную вставку
insert_query="BEGIN TRANSACTION;"

for ((i=0; i<${#game_data[@]}; i++)); do
  item="${game_data[i]}"
  IFS=',' read -r class_type game_type core extensions path <<< "$item"

  # Разделяем строку extensions с помощью разделителя '|'
  IFS='|' read -ra ext_array <<< "$extensions"

  # Формируем аргументы для команды find
  find_args=("-type" "f" "(")
  for ext in "${ext_array[@]}"; do
    find_args+=("-iname" "*.$ext" "-o")
  done
  find_args=("${find_args[@]::${#find_args[@]}-1}" ")")

  # Выполняем команду find и формируем значения для пакетной вставки
  while IFS= read -r -d '' file; do
    file_path="$(dirname "$file")"
    file_name="$(basename "$file")"
    file_extension="${file_name##*.}"
    file_name_without_extension="$(echo "${file_name%.*}" | sed -e "s/[\*\.&\[\]{}()<>$#;?!']/\\\\&/g" -e "s/'/''/g" -)"
	
    # Преобразуем расширение файла в нижний регистр и добавляем точку в начале
    file_extension_lowercase=".$(echo "${file_extension,,}")"
	
    # Проверяем, существует ли файл gstl
    gstl_file="$file_path/$file_name_without_extension.gstl"
    if [[ -f "$gstl_file" ]]; then
      # Считываем game_type из файла gstl
      gstl_cores=$(cat "$gstl_file")
    else
      # Если файл gstl не существует, оставляем gstl_cores пустым
      gstl_cores=""
    fi

    # Формируем значения для пакетной вставки
    insert_query+="INSERT INTO files VALUES ('$file_path', '$file_name_without_extension', '$file_extension_lowercase', $class_type, $game_type, '$gstl_cores');"

  done < <(find "$path" "${find_args[@]}" -print0)
done

# Завершаем пакетную вставку
insert_query+="COMMIT;"
"$sqlite" "$database_file" "$insert_query"


# Обновление значений game_type для файлов .gstl, а также удаление записей из таблиц games.db, кроме files
echo "
-- Обновление значений game_type для файлов .gstl
UPDATE files
SET game_type = gstl_cores
WHERE gstl_cores IS NOT NULL AND gstl_cores != '';

-- Удаление записей из таблиц games.db, кроме files
DELETE FROM tbl_game;
DELETE FROM tbl_en;
DELETE FROM tbl_ko;
DELETE FROM tbl_tw;
DELETE FROM tbl_zh;
DELETE FROM tbl_match;
DELETE FROM tbl_path;
DELETE FROM tbl_total;
DELETE FROM tbl_video;

BEGIN;
-- Вставка записей в таблицу tbl_game
INSERT INTO tbl_game (gameid, game, suffix, zh_id, en_id, ko_id, tw_id, video_id, class_type, game_type, hard, timer)
SELECT 
  row_number() OVER (ORDER BY file_name COLLATE NOCASE), 
  file_name, 
  extension, 
  row_number() OVER (ORDER BY file_name COLLATE NOCASE), 
  row_number() OVER (ORDER BY file_name COLLATE NOCASE), 
  row_number() OVER (ORDER BY file_name COLLATE NOCASE), 
  row_number() OVER (ORDER BY file_name COLLATE NOCASE), 
  row_number() OVER (ORDER BY file_name COLLATE NOCASE), 
  class_type, 
  game_type, 
  0, 
  '/sdcard/game/' || REPLACE(path, '../', '')
FROM files
ORDER BY file_name COLLATE NOCASE;

-- Вставка записей в другие языковые таблицы
INSERT INTO tbl_en SELECT en_id, game FROM tbl_game;
INSERT INTO tbl_ko SELECT ko_id, game FROM tbl_game;
INSERT INTO tbl_tw SELECT tw_id, game FROM tbl_game;
INSERT INTO tbl_zh SELECT zh_id, game FROM tbl_game;

-- Вставка записей в таблицу tbl_match
INSERT INTO tbl_match SELECT gameid, REPLACE(game, ' ', '') FROM tbl_game;

-- Вставка записей в таблицу tbl_path
INSERT INTO tbl_path (path_id, path) VALUES (1, '/sdcard/game');

-- Вставка записей в таблицу tbl_total
INSERT INTO tbl_total (ID, total)
SELECT gameid, gameid
FROM tbl_game
ORDER BY gameid DESC
LIMIT 1;

-- Вставка записей в таблицу tbl_video
INSERT INTO tbl_video (video_id, video, path_id)
SELECT gameid, NULL, 1
FROM tbl_game
WHERE video_id = gameid;

COMMIT;
" | "$sqlite" "$database_file"


if [ -f "$database_history" ]; then
  echo "
    ATTACH DATABASE '$database_file' AS game_db;

    -- Очистка таблицы GameInfo
    DELETE FROM GameInfo;

    -- Очистка таблицы History
    DELETE FROM History;

    -- Вставка matching записей из TempTable в GameInfo
    INSERT INTO GameInfo (GameID, STATUS)
    SELECT DISTINCT game_db.tbl_match.ID, 5
    FROM TempTable
    JOIN game_db.tbl_match ON game_db.tbl_match.zh_match = TempTable.favorites_match
    JOIN game_db.tbl_game ON game_db.tbl_game.gameid = game_db.tbl_match.ID
    WHERE game_db.tbl_match.zh_match IN (SELECT favorites_match FROM TempTable)
    AND TempTable.favorites_match IS NOT NULL
    AND TempTable.favorites_match != ''
    AND TempTable.rom_path = game_db.tbl_game.timer
    ORDER BY TempTable.sort_order;

    -- Вставка matching записей из TempTable в History
    INSERT INTO History (GameID, STATUS)
    SELECT DISTINCT game_db.tbl_match.ID, 0
    FROM TempTable
    JOIN game_db.tbl_match ON game_db.tbl_match.zh_match = TempTable.history_match
    JOIN game_db.tbl_game ON game_db.tbl_game.gameid = game_db.tbl_match.ID
    WHERE game_db.tbl_match.zh_match IN (SELECT history_match FROM TempTable)
    AND TempTable.history_match IS NOT NULL
    AND TempTable.history_match != ''
    AND TempTable.rom_path = game_db.tbl_game.timer
    ORDER BY TempTable.sort_order;

    -- Вставка записей в GameInfo для скриптов (чтобы они никогда не терялись, в случае, если бесит, то закомментируйте это)
    INSERT INTO GameInfo (GameID, STATUS)
    SELECT gameid, 5
    FROM game_db.tbl_game
    JOIN game_db.tbl_match ON game_db.tbl_match.ID = game_db.tbl_game.gameid
    WHERE game_db.tbl_game.class_type = 18;

    -- Удаление дублирующихся записей из GameInfo
    DELETE FROM GameInfo
    WHERE rowid NOT IN (
        SELECT MIN(rowid)
        FROM GameInfo
        GROUP BY GameID
    );

    -- Удаление дублирующихся записей из History
    DELETE FROM History
    WHERE rowid NOT IN (
        SELECT MIN(rowid)
        FROM History
        GROUP BY GameID
    );

    DETACH DATABASE game_db;
  " | "$sqlite" "$database_history"
fi

# Удалить таблицу 'files' из базы данных games.db
"$sqlite" "$database_file" "DROP TABLE IF EXISTS files;"

# Удалить таблицу 'TempTable' из базы данных, database.sqlite3
"$sqlite" "$database_history" "DROP TABLE IF EXISTS TempTable;"

# Экспорт отсортированных записей из игровой таблицы
# output_file="output.txt"
#"$sqlite" -csv -header "$database_file" "SELECT * FROM tbl_game ORDER BY game COLLATE NOCASE;" > "$output_file"

echo "Выполнено успешно."
exit 0
