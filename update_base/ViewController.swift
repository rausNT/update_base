//
//  ViewController.swift
//  update_base
//
//  Created by rausNT.
//

import Cocoa
import SQLite
import SQLite3
import AppKit

class ViewController: NSViewController {
    
    @IBOutlet weak var logTextView: NSScrollView!
    var textView: NSTextView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        

        // Создаем NSTextView
        textView = NSTextView(frame: logTextView.contentView.bounds)
        
        // Настраиваем внешний вид и свойства NSTextView
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isEditable = false
       // textView.isSelectable = false
        textView.autoresizingMask = [.width, .height]
        
        // Добавляем NSTextView в contentView NSScrollView
        logTextView.contentView.documentView = textView
        
        // Добавляем текст в NSTextView
       // let text = "Пример текста"
       // textView.string = text
        
    
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    

    
    
    @IBAction func runScript(_ sender: Any) {

        
        selectFolderAndCreateDatabase()
    }

  
   

    func selectFolderAndCreateDatabase() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false

        openPanel.begin { response in
            if response == NSApplication.ModalResponse.OK, let folderURL = openPanel.url {
                self.createDatabase(in: folderURL)
            }
        }
    }

    func createDatabase(in folderURL: URL) {
        
        let folderName = folderURL.lastPathComponent
        
        // Проверка имени выбранной папки
        guard folderName == "game" else {
            appendTextToTextView("Выбранная папка '\(folderName)' не является 'game'. Создание базы данных в этой папке бесполезно.")
            return
        }
        
        let fileManager = FileManager.default
        let databaseURL = folderURL.appendingPathComponent("games1.db")

        // Проверка прав доступа к каталогу
        let permissions: [FileAttributeKey: Any] = [ .posixPermissions: 0o755 ]
        do {
            try fileManager.setAttributes(permissions, ofItemAtPath: folderURL.path)
            appendTextToTextView("Права доступа к каталогу обновлены")
        } catch {
            appendTextToTextView("Не удалось обновить права доступа к каталогу: \(error)")
            return
        }


        let backupURL = folderURL.appendingPathComponent("games1.db.back")
        
        // Проверка наличия файла games1.db.back и удаление, если существует
        if fileManager.fileExists(atPath: backupURL.path) {
            do {
                try fileManager.removeItem(at: backupURL)
                appendTextToTextView("Удален файл games1.db.back")
            } catch {
                appendTextToTextView("Ошибка при удалении файла games1.db.back: \(error)")
                return
            }
        }
        
        
        // Проверка, существует ли файл уже
      
        if fileManager.fileExists(atPath: databaseURL.path) {
            let backupURL = folderURL.appendingPathComponent("games1.db.back")
            do {
                try fileManager.moveItem(at: databaseURL, to: backupURL)
                appendTextToTextView("База данных переименована в: \(backupURL.path)")
            } catch {
                appendTextToTextView("Не удалось переименовать базу данных: \(error)")
                return
            }
        }

        // Создание файла
        let success = fileManager.createFile(atPath: databaseURL.path, contents: nil, attributes: nil)
        if success {
            appendTextToTextView("База данных создана по пути: \(databaseURL.path)")
            
            // Открытие базы данных
            var db: OpaquePointer?
            if sqlite3_open(databaseURL.path, &db) == SQLITE_OK {
                appendTextToTextView("База данных открыта по пути: \(databaseURL.path)")

                // Выполнение запросов на создание таблиц и других операций
                let queries = [
                    "PRAGMA page_size = 4096;",
                    "PRAGMA auto_vacuum = FULL;",
                    "PRAGMA journal_mode = WAL;",
                    "PRAGMA temp_store = MEMORY;",
                    "PRAGMA synchronous = OFF;",
                    "BEGIN;",
                    """
                    CREATE TABLE IF NOT EXISTS tbl_game (
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
                    );
                    """,
                    "CREATE TABLE IF NOT EXISTS tbl_en (en_id INTEGER PRIMARY KEY, en_title CHAR(50));",
                    "CREATE TABLE IF NOT EXISTS tbl_ko (ko_id INTEGER PRIMARY KEY, ko_title CHAR(50));",
                    "CREATE TABLE IF NOT EXISTS tbl_zh (zh_id INTEGER PRIMARY KEY, zh_title CHAR(50));",
                    "CREATE TABLE IF NOT EXISTS tbl_tw (tw_id INTEGER PRIMARY KEY, tw_title CHAR(50));",
                    "CREATE TABLE IF NOT EXISTS tbl_match (ID INTEGER PRIMARY KEY, zh_match CHAR(50));",
                    "CREATE TABLE IF NOT EXISTS tbl_path (path_id INTEGER PRIMARY KEY, path TEXT);",
                    "CREATE TABLE IF NOT EXISTS tbl_video (video_id INTEGER, video TEXT, path_id INTEGER);",
                    "CREATE TABLE IF NOT EXISTS tbl_total (ID INTEGER, total INTEGER, PRIMARY KEY(ID));",
                    "CREATE TABLE IF NOT EXISTS files (path CHAR(50), file_name CHAR(50), extension CHAR(5), class_type INTEGER, game_type INTEGER, gstl_cores INTEGER);",
                    "COMMIT;",
                    "DELETE FROM tbl_game;",
                    "DELETE FROM tbl_en;",
                    "DELETE FROM tbl_ko;",
                    "DELETE FROM tbl_tw;",
                    "DELETE FROM tbl_zh;",
                    "DELETE FROM tbl_match;",
                    "DELETE FROM tbl_path;",
                    "DELETE FROM tbl_total;",
                    "DELETE FROM tbl_video;"
                ]

                for query in queries {
                    if sqlite3_exec(db, query, nil, nil, nil) == SQLITE_OK {
                        appendTextToTextView("Запрос выполнен успешно: \(query)")
                    } else {
                        appendTextToTextView("Ошибка выполнения запроса: \(query)")
                    }
                }

                // Закрытие базы данных
                if sqlite3_close(db) == SQLITE_OK {
                    appendTextToTextView("База данных закрыта")
                    
                    insertGameFilesIntoDatabase(folderURL: folderURL)
                    
                } else {
                    appendTextToTextView("Не удалось закрыть базу данных")
                }
            } else {
                appendTextToTextView("Не удалось открыть базу данных")
            }
            
            
        } else {
            appendTextToTextView("Не удалось создать базу данных по пути: \(databaseURL.path)")
        }
    }


    //////////////////////
    ///
    ///
 

    ///++++++++++++++++++++++++++++
    func insertGameFilesIntoDatabase(folderURL: URL) {
        let databaseURL = folderURL.appendingPathComponent("games1.db")
        let currentURL = folderURL
        
        // Проверка наличия базы данных
        if !FileManager.default.fileExists(atPath: databaseURL.path) {
            appendTextToTextView("База данных не существует по пути: \(databaseURL.path)")
            return
        }
        
        var gameFiles: [[String: Any]] = []
        var cleanedGames: [String] = [] // Массив для хранения очищенных имен игр
        
        let allowedSubfolders = ["atari", "cps", "ds", "fc", "gb", "gba", "gbc", "md", "n64", "pcengine", "ps1", "saturn", "sfc", "spec", "dreamcast", "scummvm", "dos", "fbneo", "j2me"]
        let allowedExtensions = ["a26", "a78", "a52", "zip", "nds", "bin", "nes", "fds", "unf", "unif", "gb", "gba", "gbc", "mdx", "md", "smd", "gen", "bin", "cue", "iso", "sms", "gg", "sg", "68k", "chd", "32x", "n64", "v64", "z64", "bin", "u1", "ndd", "gb", "pce", "cue", "ccd", "iso", "img", "bin", "chd", "bin", "img", "mdf", "pbp", "toc", "cbn", "m3u", "cue", "iso", "ccd", "mds", "chd", "zip", "m3u", "smc", "sfc", "swc", "fig", "bs", "st", "tzx", "tap", "z80", "rzx", "scl", "trd", "cdi", "gdi", "chd", "cue", "bin", "elf", "zip", "7z", "lst", "dat", "m3u", "scummvm", "exe", "com", "bat", "iso", "cue", "conf", "zip", "7z", "jad", "jar"]
        
        // Рекурсивный поиск файлов в подпапках
        func findFilesRecursively(in folderURL: URL) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                
                for fileURL in contents {
                    var isDirectory: ObjCBool = false
                    
                    // Проверяем, является ли файл папкой
                    if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                        let subfolderName = fileURL.lastPathComponent
                        
                        // Проверяем, находится ли подпапка в списке разрешенных
                        if allowedSubfolders.contains(subfolderName) {
                            findFilesRecursively(in: fileURL) // Рекурсивный вызов для разрешенных подпапок
                        }
                    } else {
                        // Проверяем, чтобы файл не был из исходной папки
                        if currentURL.path != fileURL.deletingLastPathComponent().path {
                            let gameID = gameFiles.count + 1
                            let game = fileURL.deletingPathExtension().lastPathComponent
                            let suffix = fileURL.pathExtension
                            
                            // Проверяем, находится ли расширение файла в списке разрешенных
                            if allowedExtensions.contains(suffix) {
                                let zhID = gameID
                                let enID = gameID
                                let koID = gameID
                                let twID = gameID
                                let videoID = gameID
                                let classType = 1
                                let gameType = 1
                                let hard = 0
                                let timer = "/sdcard/game/" + folderURL.lastPathComponent
                                
                                // Очистка значений от символов, которые могут помешать вставке
                                let cleanedGame = game.replacingOccurrences(of: "'", with: "''")
                                let cleanedGameLowercased = cleanedGame.lowercased()
                                
                                let gameFile: [String: Any] = [
                                    "gameid": gameID,
                                    "game": cleanedGame,
                                    "suffix": suffix,
                                    "zh_id": zhID,
                                    "en_id": enID,
                                    "ko_id": koID,
                                    "tw_id": twID,
                                    "video_id": videoID,
                                    "class_type": classType,
                                    "game_type": gameType,
                                    "hard": hard,
                                    "timer": timer,
                                    "cleanedGameLowercased": cleanedGame
                                ]
                                
                                gameFiles.append(gameFile)
                                cleanedGames.append(cleanedGameLowercased)
                            }
                        }
                    }
                }
            } catch {
                appendTextToTextView("Ошибка при получении содержимого папки: \(error)")
                return
            }
        }
        
        findFilesRecursively(in: folderURL)
        
        // Открытие базы данных
        var db: OpaquePointer?
        
        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            appendTextToTextView("Не удалось открыть базу данных")
            return
        }
        
        // Выполнение транзакции
        if sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil) != SQLITE_OK {
            appendTextToTextView("Не удалось начать транзакцию")
            sqlite3_close(db)
            return
        }
        
        // Выполнение запросов INSERT
        for gameFile in gameFiles {
            let gameID = gameFile["gameid"] as? Int ?? 0
            let game = gameFile["game"] as? String ?? ""
            let suffix = gameFile["suffix"] as? String ?? ""
            let zhID = gameFile["zh_id"] as? Int ?? 0
            let enID = gameFile["en_id"] as? Int ?? 0
            let koID = gameFile["ko_id"] as? Int ?? 0
            let twID = gameFile["tw_id"] as? Int ?? 0
            let videoID = gameFile["video_id"] as? Int ?? 0
            let classType = gameFile["class_type"] as? Int ?? 0
            let gameType = gameFile["game_type"] as? Int ?? 0
            let hard = gameFile["hard"] as? Int ?? 0
            let timer = gameFile["timer"] as? String ?? ""
            let cleanedGameLowercased = gameFile["cleanedGameLowercased"] as? String ?? ""
            
            let insertQuery = """
                INSERT INTO tbl_game (gameid, game, suffix, zh_id, en_id, ko_id, tw_id, video_id, class_type, game_type, hard, timer)
                VALUES (\(gameID), '\(game)', '\(suffix)', \(zhID), \(enID), \(koID), \(twID), \(videoID), \(classType), \(gameType), \(hard), '\(timer)')
            """
            
            if sqlite3_exec(db, insertQuery, nil, nil, nil) != SQLITE_OK {
                appendTextToTextView("Не удалось выполнить запрос INSERT")
                sqlite3_close(db)
                return
            }
            
            // Вставка данных в таблицу tbl_match
            let insertMatchQuery = """
                INSERT INTO tbl_match (ID, zh_match)
                VALUES (\(gameID), '\(cleanedGameLowercased)')
            """
            
            if sqlite3_exec(db, insertMatchQuery, nil, nil, nil) != SQLITE_OK {
                appendTextToTextView("Не удалось выполнить запрос INSERT для таблицы tbl_match")
                sqlite3_close(db)
                return
            }
            
            // Вставка данных в таблицу tbl_video
            let insertVideoQuery = """
            INSERT INTO tbl_video (video_id, video, path_id)
            VALUES (\(gameID), NULL, 1)
            """

            if sqlite3_exec(db, insertVideoQuery, nil, nil, nil) != SQLITE_OK {
                appendTextToTextView("Не удалось выполнить запрос INSERT для таблицы tbl_video")
                sqlite3_close(db)
                return
            }
        }
        
        // Вставка данных в таблицу tbl_en
        let insertEnQuery = """
            INSERT INTO tbl_en (en_id, en_title)
            SELECT gameid, game FROM tbl_game
        """
        
        if sqlite3_exec(db, insertEnQuery, nil, nil, nil) != SQLITE_OK {
            appendTextToTextView("Не удалось выполнить запрос INSERT для таблицы tbl_en")
            sqlite3_close(db)
            return
        }
        
        // Вставка данных в таблицу tbl_ko
        let insertKoQuery = """
            INSERT INTO tbl_ko (ko_id, ko_title)
            SELECT gameid, game FROM tbl_game
        """
        
        if sqlite3_exec(db, insertKoQuery, nil, nil, nil) != SQLITE_OK {
            appendTextToTextView("Не удалось выполнить запрос INSERT для таблицы tbl_ko")
            sqlite3_close(db)
            return
        }
        
        // Вставка данных в таблицу tbl_tw
        let insertTwQuery = """
            INSERT INTO tbl_tw (tw_id, tw_title)
            SELECT gameid, game FROM tbl_game
        """
        
        if sqlite3_exec(db, insertTwQuery, nil, nil, nil) != SQLITE_OK {
            appendTextToTextView("Не удалось выполнить запрос INSERT для таблицы tbl_tw")
            sqlite3_close(db)
            return
        }
        
        // Вставка данных в таблицу tbl_zh
        let insertZhQuery = """
            INSERT INTO tbl_zh (zh_id, zh_title)
            SELECT gameid, game FROM tbl_game
        """
        
        if sqlite3_exec(db, insertZhQuery, nil, nil, nil) != SQLITE_OK {
            appendTextToTextView("Не удалось выполнить запрос INSERT для таблицы tbl_zh")
            sqlite3_close(db)
            return
        }
        
        // Вставка данных в таблицу tbl_path
        let insertPathQuery = """
            INSERT INTO tbl_path (path_id, path)
            VALUES (1, '/sdcard/game/')
        """
        
        if sqlite3_exec(db, insertPathQuery, nil, nil, nil) != SQLITE_OK {
            appendTextToTextView("Не удалось выполнить запрос INSERT для таблицы tbl_path")
            sqlite3_close(db)
            return
        }
        
        
        
        // Вставка данных в таблицу tbl_total
        let total = gameFiles.count
        let insertTotalQuery = """
            INSERT INTO tbl_total (ID, total)
            VALUES (1, \(total))
        """
        
        if sqlite3_exec(db, insertTotalQuery, nil, nil, nil) != SQLITE_OK {
            appendTextToTextView("Не удалось выполнить запрос INSERT для таблицы tbl_total")
            sqlite3_close(db)
            return
        }
        
        // Завершение транзакции
        if sqlite3_exec(db, "COMMIT;", nil, nil, nil) != SQLITE_OK {
            appendTextToTextView("Не удалось завершить транзакцию")
        }
        
        sqlite3_close(db)
        
        
        appendTextToTextView("Вставка файлов в базу данных выполнена успешно")
    }




/////////////////////////////========
    
    
    
    func appendTextToTextView(_ text: String) {
        DispatchQueue.main.async {
            self.textView.string.append("\(text)\n")
            let range = NSRange(location: self.textView.string.count, length: 0)
            self.textView.scrollRangeToVisible(range)
        }
    }



 
    
   
}

