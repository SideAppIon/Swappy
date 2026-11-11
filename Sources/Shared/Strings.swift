import Foundation

/// In-code localization shared by the app and the widget.
/// Column order: en, ru, de, fr, es, pt, zh, ja.
enum L10n {
    static let codes = ["en", "ru", "de", "fr", "es", "pt", "zh", "ja"]
    static let names = ["English", "Русский", "Deutsch", "Français", "Español", "Português", "简体中文", "日本語"]

    /// nil = follow the system language.
    static var override: String? { didSet { index = resolve() } }
    private(set) static var index = resolve()

    static var locale: Locale { Locale(identifier: codes[index] == "zh" ? "zh-Hans" : codes[index]) }

    private static func resolve() -> Int {
        if let o = override, let i = codes.firstIndex(of: o) { return i }
        for lang in Locale.preferredLanguages {
            if let i = codes.firstIndex(where: { lang.hasPrefix($0) }) { return i }
        }
        return 0
    }

    static func pick<T>(_ values: [T]) -> T { values[min(index, values.count - 1)] }
}

func L(_ key: String, _ args: CVarArg...) -> String {
    guard let row = Strings.table[key] else { return key }
    let s = L10n.pick(row)
    return args.isEmpty ? s : String(format: s, arguments: args)
}

enum Strings {
    static let byteUnits: [[String]] = [
        ["B", "KB", "MB", "GB", "TB"], ["Б", "КБ", "МБ", "ГБ", "ТБ"], ["B", "KB", "MB", "GB", "TB"],
        ["o", "Ko", "Mo", "Go", "To"], ["B", "KB", "MB", "GB", "TB"], ["B", "KB", "MB", "GB", "TB"],
        ["B", "KB", "MB", "GB", "TB"], ["B", "KB", "MB", "GB", "TB"],
    ]
    /// day, hour, minute
    static let timeUnits: [[String]] = [
        ["d", "h", "min"], ["дн", "ч", "мин"], ["T", "Std", "Min"], ["j", "h", "min"],
        ["d", "h", "min"], ["d", "h", "min"], ["天", "小时", "分钟"], ["日", "時間", "分"],
    ]

    static let table: [String: [String]] = [
        // Header & settings
        "mem.ok": ["Memory OK", "Память в норме", "Speicher OK", "Mémoire OK", "Memoria OK", "Memória OK", "内存正常", "メモリ正常"],
        "mem.warn": ["Memory under pressure", "Память под давлением", "Speicher unter Druck", "Mémoire sous pression", "Memoria bajo presión", "Memória sob pressão", "内存压力较大", "メモリ逼迫"],
        "mem.crit": ["Out of memory", "Нехватка памяти", "Speichermangel", "Mémoire saturée", "Falta memoria", "Falta de memória", "内存不足", "メモリ不足"],
        "mem.help": ["Memory pressure as reported by macOS. The higher it is, the more the system writes to swap.", "Давление на память по оценке macOS. Чем оно выше, тем активнее система пишет в swap.", "Speicherdruck laut macOS. Je höher, desto mehr schreibt das System in den Swap.", "Pression mémoire selon macOS. Plus elle est élevée, plus le système écrit dans le swap.", "Presión de memoria según macOS. Cuanto mayor es, más escribe el sistema en swap.", "Pressão de memória segundo o macOS. Quanto maior, mais o sistema grava no swap.", "macOS 报告的内存压力。压力越大，系统写入交换文件越频繁。", "macOS が報告するメモリプレッシャー。高いほどスワップへの書き込みが増えます。"],
        "set.title": ["Settings", "Настройки", "Einstellungen", "Réglages", "Ajustes", "Ajustes", "设置", "設定"],
        "set.theme": ["Theme", "Тема", "Design", "Thème", "Tema", "Tema", "主题", "テーマ"],
        "theme.system": ["Match system", "Как в системе", "Wie System", "Comme le système", "Como el sistema", "Como o sistema", "跟随系统", "システムに合わせる"],
        "theme.light": ["Light", "Светлая", "Hell", "Clair", "Claro", "Claro", "浅色", "ライト"],
        "theme.dark": ["Dark", "Тёмная", "Dunkel", "Sombre", "Oscuro", "Escuro", "深色", "ダーク"],
        "set.bar": ["Menu bar", "В строке меню", "Menüleiste", "Barre des menus", "Barra de menús", "Barra de menus", "菜单栏", "メニューバー"],
        "bar.swap": ["Swap size", "Объём swap", "Swap-Größe", "Taille du swap", "Tamaño de swap", "Tamanho do swap", "交换大小", "スワップ量"],
        "bar.swapmem": ["Swap and memory", "Swap и память", "Swap und Speicher", "Swap et mémoire", "Swap y memoria", "Swap e memória", "交换和内存", "スワップとメモリ"],
        "bar.icon": ["Icon only", "Только значок", "Nur Symbol", "Icône seule", "Solo icono", "Só ícone", "仅图标", "アイコンのみ"],
        "set.lang": ["Language", "Язык", "Sprache", "Langue", "Idioma", "Idioma", "语言", "言語"],
        "lang.system": ["System", "Как в системе", "System", "Système", "Sistema", "Sistema", "跟随系统", "システム"],
        "set.login": ["Launch at login", "Запускать при входе", "Bei Anmeldung starten", "Ouvrir à la connexion", "Abrir al iniciar sesión", "Abrir ao iniciar sessão", "登录时启动", "ログイン時に起動"],
        "set.quit": ["Quit Swappy", "Завершить Swappy", "Swappy beenden", "Quitter Swappy", "Salir de Swappy", "Encerrar Swappy", "退出 Swappy", "Swappy を終了"],
        "back": ["Back", "Назад", "Zurück", "Retour", "Atrás", "Voltar", "返回", "戻る"],
        "na": ["n/a", "н/д", "k. A.", "n/d", "n/d", "n/d", "无", "なし"],
        "per.s": ["%@/s", "%@/с", "%@/s", "%@/s", "%@/s", "%@/s", "%@/秒", "%@/秒"],
        "per.day": ["%@/day", "%@/день", "%@/Tag", "%@/jour", "%@/día", "%@/dia", "%@/天", "%@/日"],
        "x.of.y": ["%@ of %@", "%@ из %@", "%@ von %@", "%@ sur %@", "%@ de %@", "%@ de %@", "%@ / %@", "%@ / %@"],

        // Swap card
        "swap.title": ["SWAP FILE", "ФАЙЛ ПОДКАЧКИ", "AUSLAGERUNGSDATEI", "FICHIER D’ÉCHANGE", "ARCHIVO DE INTERCAMBIO", "ARQUIVO DE TROCA", "交换文件", "スワップファイル"],
        "swap.name": ["Swap file", "Файл подкачки", "Auslagerungsdatei", "Fichier d’échange", "Archivo de intercambio", "Arquivo de troca", "交换文件", "スワップファイル"],
        "swap.of": ["used of %@ reserved", "занято из %@ выделенных", "belegt von %@ reserviert", "utilisés sur %@ réservés", "usados de %@ reservados", "usados de %@ reservados", "已用，共预留 %@", "使用中（確保済み %@）"],
        "st.heavy": ["Heavy disk writes", "Активная запись на диск", "Starke Schreiblast", "Écriture intense", "Escritura intensa", "Gravação intensa", "磁盘写入频繁", "書き込み多発"],
        "st.writing": ["Writing to disk", "Идёт запись на диск", "Schreibt auf SSD", "Écriture en cours", "Escribiendo en disco", "Gravando no disco", "正在写入磁盘", "ディスクに書き込み中"],
        "st.unused": ["Not in use", "Не используется", "Nicht verwendet", "Inutilisé", "Sin usar", "Sem uso", "未使用", "未使用"],
        "st.idle": ["Disk is resting", "Диск отдыхает", "SSD ruht", "Disque au repos", "Disco en reposo", "Disco em repouso", "磁盘空闲", "ディスク休止中"],
        "swap.why": ["Why is it used?", "Почему занято?", "Warum belegt?", "Pourquoi ?", "¿Por qué?", "Por quê?", "为什么被占用？", "なぜ使用中？"],
        "swap.written": ["Written in %@", "Записано за %@", "Geschrieben in %@", "Écrit en %@", "Escrito en %@", "Gravado em %@", "%@内写入", "%@で書き込み"],
        "swap.avg": ["Daily average", "В среднем", "Tagesschnitt", "Moyenne par jour", "Media diaria", "Média diária", "日均", "1日平均"],
        "swap.now": ["Writing now", "Запись сейчас", "Schreibt jetzt", "Écriture actuelle", "Escritura ahora", "Gravando agora", "当前写入", "現在の書き込み"],
        "swap.written.help": ["How much macOS has written to swap since the Mac was last started (%@ ago). Writing, not occupied space, is what wears an SSD.", "Сколько данных macOS записала в swap с последнего включения Mac (%@ назад). SSD изнашивает именно запись, а не занятое место.", "So viel hat macOS seit dem letzten Start des Mac (vor %@) in den Swap geschrieben. Schreiben, nicht belegter Platz, nutzt die SSD ab.", "Quantité écrite dans le swap depuis le dernier démarrage du Mac (il y a %@). C’est l’écriture, pas l’espace occupé, qui use le SSD.", "Cuánto ha escrito macOS en swap desde el último arranque del Mac (hace %@). La escritura, no el espacio ocupado, desgasta el SSD.", "Quanto o macOS gravou no swap desde a última inicialização do Mac (há %@). É a gravação, não o espaço ocupado, que desgasta o SSD.", "自上次开机（%@前）以来 macOS 写入交换文件的数据量。损耗 SSD 的是写入，而不是占用的空间。", "Mac の前回起動（%@前）以降にスワップへ書き込まれた量。SSD を消耗させるのは使用量ではなく書き込みです。"],
        "hist.wait": ["Collecting history…", "Собираю историю…", "Verlauf wird gesammelt…", "Collecte de l’historique…", "Recopilando historial…", "Coletando histórico…", "正在收集历史…", "履歴を収集中…"],
        "hist.help": ["Swap in use over the last 10 minutes", "Занятый swap за последние 10 минут", "Belegter Swap der letzten 10 Minuten", "Swap utilisé sur les 10 dernières minutes", "Swap usado en los últimos 10 minutos", "Swap usado nos últimos 10 minutos", "最近 10 分钟的交换占用", "過去10分間のスワップ使用量"],

        // Tiles
        "cpu": ["CPU", "Процессор", "CPU", "Processeur", "CPU", "CPU", "处理器", "CPU"],
        "gpu": ["GPU", "Графика", "GPU", "GPU", "GPU", "GPU", "显卡", "GPU"],
        "ram": ["Memory", "Память", "Speicher", "Mémoire", "Memoria", "Memória", "内存", "メモリ"],
        "ssd": ["Disk", "Диск", "SSD", "Disque", "Disco", "Disco", "磁盘", "ディスク"],
        "net": ["Network", "Сеть", "Netzwerk", "Réseau", "Red", "Rede", "网络", "ネットワーク"],
        "tile.help": ["Click for details", "Нажмите, чтобы увидеть подробности", "Für Details klicken", "Cliquez pour les détails", "Clic para ver detalles", "Clique para detalhes", "点击查看详情", "クリックで詳細"],

        // Apps
        "apps.title": ["WHAT IS USING SWAP", "КТО ЗАНИМАЕТ SWAP", "WER BELEGT DEN SWAP", "QUI UTILISE LE SWAP", "QUIÉN USA EL SWAP", "QUEM USA O SWAP", "谁在占用交换", "スワップを使用中のアプリ"],
        "apps.title.c": ["COMPRESSED MEMORY BY APP", "СЖАТАЯ ПАМЯТЬ ПО ПРОГРАММАМ", "KOMPRIMIERTER SPEICHER JE APP", "MÉMOIRE COMPRESSÉE PAR APP", "MEMORIA COMPRIMIDA POR APP", "MEMÓRIA COMPRIMIDA POR APP", "各应用的压缩内存", "アプリ別の圧縮メモリ"],
        "apps.info": ["macOS first compresses rarely used app memory, then moves compressed data to swap. The system doesn't reveal whose data is already on disk, so each app's swap share (≈) is estimated in proportion to its compressed memory. Helper processes (tabs, renderers) are counted with their app.", "macOS сначала сжимает редко используемую память программ, а затем выгружает сжатые данные в swap. Система не сообщает, чьи именно данные уже на диске, поэтому доля swap (≈) рассчитана пропорционально сжатой памяти каждой программы. Вспомогательные процессы (вкладки, рендереры) отнесены к своей программе.", "macOS komprimiert zuerst selten genutzten App-Speicher und lagert komprimierte Daten dann in den Swap aus. Das System verrät nicht, wessen Daten schon auf der SSD liegen; der Swap-Anteil (≈) jeder App wird daher proportional zu ihrem komprimierten Speicher geschätzt. Hilfsprozesse (Tabs, Renderer) zählen zu ihrer App.", "macOS compresse d’abord la mémoire peu utilisée des apps, puis déplace les données compressées vers le swap. Le système n’indique pas quelles données sont déjà sur disque : la part de swap (≈) de chaque app est estimée au prorata de sa mémoire compressée. Les processus auxiliaires (onglets, moteurs de rendu) sont comptés avec leur app.", "macOS primero comprime la memoria poco usada de las apps y luego mueve los datos comprimidos a swap. El sistema no revela de quién son los datos ya en disco, así que la parte de swap (≈) de cada app se estima en proporción a su memoria comprimida. Los procesos auxiliares (pestañas, renderizadores) se cuentan con su app.", "O macOS primeiro comprime a memória pouco usada dos apps e depois move os dados comprimidos para o swap. O sistema não revela de quem são os dados já em disco, então a parte de swap (≈) de cada app é estimada em proporção à sua memória comprimida. Processos auxiliares (abas, renderizadores) contam com seu app.", "macOS 会先压缩应用中很少使用的内存，再把压缩数据移到交换文件。系统不会透露哪些数据已在磁盘上，因此各应用的交换占比（≈）按其压缩内存比例估算。辅助进程（标签页、渲染器）计入所属应用。", "macOS はまず使用頻度の低いメモリを圧縮し、その後圧縮データをスワップへ移します。どのデータがディスク上にあるかは公開されないため、各アプリのスワップ量（≈）は圧縮メモリに比例した推定値です。補助プロセス（タブ、レンダラー）は親アプリに含めています。"],
        "apps.wait": ["Calculating…", "Считаю…", "Berechne…", "Calcul…", "Calculando…", "Calculando…", "计算中…", "計算中…"],
        "apps.row": ["compressed %@ · total memory %@", "сжато %@ · всего памяти %@", "komprimiert %@ · gesamt %@", "compressé %@ · total %@", "comprimido %@ · total %@", "comprimido %@ · total %@", "已压缩 %@ · 总内存 %@", "圧縮 %@ · 合計 %@"],
        "quit.ask": ["Quit %@?", "Завершить «%@»?", "%@ beenden?", "Quitter %@ ?", "¿Salir de %@?", "Encerrar %@?", "退出 %@？", "%@ を終了しますか？"],
        "quit.warn": ["Unsaved changes may be lost.", "Несохранённые данные могут быть потеряны.", "Ungesicherte Änderungen können verloren gehen.", "Les modifications non enregistrées peuvent être perdues.", "Los cambios sin guardar pueden perderse.", "Alterações não salvas podem ser perdidas.", "未保存的更改可能会丢失。", "未保存の変更は失われる可能性があります。"],
        "quit.yes": ["Quit", "Завершить", "Beenden", "Quitter", "Salir", "Encerrar", "退出", "終了"],
        "cancel": ["Cancel", "Отмена", "Abbrechen", "Annuler", "Cancelar", "Cancelar", "取消", "キャンセル"],
        "quit.help": ["Quit %@ to free its swap", "Завершить «%@» и освободить её swap", "%@ beenden und Swap freigeben", "Quitter %@ pour libérer son swap", "Salir de %@ para liberar su swap", "Encerrar %@ para liberar o swap", "退出 %@ 以释放其交换空间", "%@ を終了してスワップを解放"],

        // CPU
        "cpu.load": ["LOAD", "ЗАГРУЗКА", "AUSLASTUNG", "CHARGE", "CARGA", "CARGA", "负载", "負荷"],
        "cpu.user": ["Apps", "Программы", "Apps", "Apps", "Apps", "Apps", "应用", "アプリ"],
        "cpu.system": ["System", "Система", "System", "Système", "Sistema", "Sistema", "系统", "システム"],
        "cpu.idle": ["Idle", "Простой", "Leerlauf", "Inactif", "Inactivo", "Ocioso", "空闲", "アイドル"],
        "cpu.cores": ["PER-CORE LOAD", "ЗАГРУЗКА ЯДЕР", "KERNAUSLASTUNG", "CHARGE PAR CŒUR", "CARGA POR NÚCLEO", "CARGA POR NÚCLEO", "各核心负载", "コア別負荷"],
        "cpu.count": ["%d cores", "%d ядер", "%d Kerne", "%d cœurs", "%d núcleos", "%d núcleos", "%d 核", "%d コア"],
        "cpu.pe": ["%d performance + %d efficiency", "%d производительных + %d энергоэффективных", "%d Performance + %d Effizienz", "%d performance + %d efficacité", "%d rendimiento + %d eficiencia", "%d desempenho + %d eficiência", "%d 性能核 + %d 能效核", "高性能 %d + 高効率 %d"],
        "cpu.threads": ["%d cores, %d threads", "%d ядер, %d потоков", "%d Kerne, %d Threads", "%d cœurs, %d threads", "%d núcleos, %d hilos", "%d núcleos, %d threads", "%d 核 %d 线程", "%d コア / %d スレッド"],
        "pwr.title": ["POWER AND HEAT", "ЭНЕРГИЯ И НАГРЕВ", "LEISTUNG UND WÄRME", "PUISSANCE ET CHALEUR", "ENERGÍA Y CALOR", "ENERGIA E CALOR", "功耗与温度", "電力と温度"],
        "pwr.cpu": ["CPU power draw", "Потребление процессора", "CPU-Leistungsaufnahme", "Consommation du CPU", "Consumo de la CPU", "Consumo da CPU", "处理器功耗", "CPU 消費電力"],
        "pwr.gpu": ["GPU power draw", "Потребление графики", "GPU-Leistungsaufnahme", "Consommation du GPU", "Consumo de la GPU", "Consumo da GPU", "显卡功耗", "GPU 消費電力"],
        "pwr.sys": ["Whole Mac power draw", "Потребление всего Mac", "Leistungsaufnahme gesamt", "Consommation totale du Mac", "Consumo total del Mac", "Consumo total do Mac", "整机功耗", "Mac 全体の消費電力"],
        "temp": ["Temperature", "Температура", "Temperatur", "Température", "Temperatura", "Temperatura", "温度", "温度"],
        "thermal": ["Thermal state", "Тепловое состояние", "Thermischer Zustand", "État thermique", "Estado térmico", "Estado térmico", "散热状态", "熱状態"],
        "th.0": ["Normal", "Норма", "Normal", "Normal", "Normal", "Normal", "正常", "正常"],
        "th.1": ["Warm", "Тепло", "Warm", "Tiède", "Templado", "Morno", "偏热", "やや高温"],
        "th.2": ["Hot, performance reduced", "Горячо, скорость снижена", "Heiß, Leistung gedrosselt", "Chaud, performances réduites", "Caliente, rendimiento reducido", "Quente, desempenho reduzido", "过热，已降速", "高温・性能低下"],
        "th.3": ["Critical", "Критическое", "Kritisch", "Critique", "Crítico", "Crítico", "严重", "危険"],
        "fans": ["Fans", "Вентиляторы", "Lüfter", "Ventilateurs", "Ventiladores", "Ventoinhas", "风扇", "ファン"],
        "rpm": ["%@ rpm", "%@ об/мин", "%@ U/min", "%@ tr/min", "%@ rpm", "%@ rpm", "%@ 转/分", "%@ rpm"],
        "loadavg": ["Load average 1 / 5 / 15 min", "Средняя нагрузка 1 / 5 / 15 мин", "Durchschnittslast 1 / 5 / 15 Min", "Charge moyenne 1 / 5 / 15 min", "Carga media 1 / 5 / 15 min", "Carga média 1 / 5 / 15 min", "平均负载 1 / 5 / 15 分钟", "平均負荷 1 / 5 / 15 分"],
        "uptime": ["Uptime", "Время работы", "Laufzeit", "Temps de fonctionnement", "Tiempo encendido", "Tempo ligado", "运行时间", "稼働時間"],
        "sensor.none": ["Power and temperature sensors are not available on this Mac.", "Датчики мощности и температуры на этом Mac недоступны.", "Leistungs- und Temperatursensoren sind auf diesem Mac nicht verfügbar.", "Capteurs de puissance et de température indisponibles sur ce Mac.", "Los sensores de energía y temperatura no están disponibles en este Mac.", "Sensores de energia e temperatura indisponíveis neste Mac.", "此 Mac 上无法读取功耗和温度传感器。", "この Mac では電力・温度センサーを利用できません。"],

        // GPU
        "gpu.util": ["Utilization", "Загрузка", "Auslastung", "Utilisation", "Uso", "Uso", "利用率", "使用率"],
        "gpu.vram": ["Video memory in use", "Занято видеопамяти", "Belegter Grafikspeicher", "Mémoire vidéo utilisée", "Memoria de vídeo en uso", "Memória de vídeo em uso", "已用显存", "使用中のビデオメモリ"],
        "gpu.idle": ["No activity reported — this GPU is not in use right now.", "Нет данных об активности — эта видеокарта сейчас не используется.", "Keine Aktivität gemeldet – diese GPU wird gerade nicht genutzt.", "Aucune activité signalée — ce GPU n’est pas utilisé actuellement.", "Sin actividad: esta GPU no se está usando ahora.", "Sem atividade — esta GPU não está em uso agora.", "未报告活动——此显卡当前未在使用。", "アクティビティなし — この GPU は現在使用されていません。"],
        "gpu.none": ["This Mac doesn't report GPU statistics.", "Этот Mac не сообщает статистику графики.", "Dieser Mac meldet keine GPU-Statistiken.", "Ce Mac ne fournit pas de statistiques GPU.", "Este Mac no ofrece estadísticas de GPU.", "Este Mac não informa estatísticas de GPU.", "此 Mac 不提供显卡统计。", "この Mac は GPU 統計を提供していません。"],

        // RAM
        "ram.breakdown": ["WHAT MEMORY IS USED FOR", "НА ЧТО УХОДИТ ПАМЯТЬ", "WOFÜR SPEICHER GENUTZT WIRD", "RÉPARTITION DE LA MÉMOIRE", "EN QUÉ SE USA LA MEMORIA", "COMO A MEMÓRIA É USADA", "内存用途", "メモリの内訳"],
        "ram.app": ["Apps", "Программы", "Apps", "Apps", "Apps", "Apps", "应用", "アプリ"],
        "ram.wired": ["System (wired)", "Система", "System (reserviert)", "Système (câblée)", "Sistema (fija)", "Sistema (fixa)", "系统（联动）", "システム（確保）"],
        "ram.comp": ["Compressed", "Сжатая", "Komprimiert", "Compressée", "Comprimida", "Comprimida", "已压缩", "圧縮"],
        "ram.cache": ["File cache", "Кэш файлов", "Dateicache", "Cache de fichiers", "Caché de archivos", "Cache de arquivos", "文件缓存", "ファイルキャッシュ"],
        "ram.free": ["Free", "Свободно", "Frei", "Libre", "Libre", "Livre", "空闲", "空き"],
        "ram.app.d": ["Memory actively held by running apps", "Память, занятая запущенными программами", "Von laufenden Apps belegter Speicher", "Mémoire occupée par les apps ouvertes", "Memoria ocupada por las apps abiertas", "Memória ocupada pelos apps abertos", "运行中的应用占用的内存", "実行中のアプリが使用中"],
        "ram.wired.d": ["Kernel and drivers; can't be compressed or swapped", "Ядро и драйверы; нельзя сжать или выгрузить", "Kernel und Treiber; nicht komprimier- oder auslagerbar", "Noyau et pilotes ; ni compressible ni déplaçable", "Núcleo y controladores; no se puede comprimir ni mover", "Kernel e drivers; não pode ser comprimida nem movida", "内核与驱动；无法压缩或换出", "カーネルとドライバ。圧縮・退避不可"],
        "ram.comp.d": ["Space taken by compressed data of idle apps", "Место под сжатые данные неактивных программ", "Platz für komprimierte Daten inaktiver Apps", "Espace des données compressées des apps inactives", "Espacio de los datos comprimidos de apps inactivas", "Espaço dos dados comprimidos de apps inativos", "闲置应用的压缩数据所占空间", "休止中アプリの圧縮データ"],
        "ram.cache.d": ["Recently used files; freed instantly when needed", "Недавние файлы; освобождается мгновенно при необходимости", "Kürzlich genutzte Dateien; bei Bedarf sofort frei", "Fichiers récents ; libéré instantanément si besoin", "Archivos recientes; se libera al instante si hace falta", "Arquivos recentes; liberado na hora se necessário", "最近使用的文件；需要时立即释放", "最近使用したファイル。必要時に即解放"],
        "ram.free.d": ["Not used for anything", "Ничем не занято", "Ungenutzt", "Inutilisée", "Sin usar", "Sem uso", "未被使用", "未使用"],
        "ram.installed": ["Installed", "Установлено", "Installiert", "Installée", "Instalada", "Instalada", "已安装", "搭載"],
        "ram.used": ["In use", "Используется", "Belegt", "Utilisée", "En uso", "Em uso", "已使用", "使用中"],
        "ram.pressure": ["Pressure", "Давление", "Druck", "Pression", "Presión", "Pressão", "压力", "プレッシャー"],
        "pr.1": ["Normal", "Норма", "Normal", "Normale", "Normal", "Normal", "正常", "正常"],
        "pr.2": ["Elevated", "Повышенное", "Erhöht", "Élevée", "Elevada", "Elevada", "偏高", "高め"],
        "pr.4": ["Critical", "Критическое", "Kritisch", "Critique", "Crítica", "Crítica", "严重", "危険"],
        "ram.compression": ["COMPRESSION AND SWAP", "СЖАТИЕ И SWAP", "KOMPRIMIERUNG UND SWAP", "COMPRESSION ET SWAP", "COMPRESIÓN Y SWAP", "COMPRESSÃO E SWAP", "压缩与交换", "圧縮とスワップ"],
        "ram.stored": ["Data handed to the compressor", "Данных передано на сжатие", "An Kompressor übergebene Daten", "Données confiées au compresseur", "Datos enviados al compresor", "Dados enviados ao compressor", "交给压缩器的数据", "圧縮対象データ"],
        "ram.inram": ["Kept compressed in memory", "Из них лежит в памяти (сжато)", "Davon komprimiert im Speicher", "Dont en mémoire (compressé)", "De ellos en memoria (comprimido)", "Deles na memória (comprimido)", "其中压缩后留在内存", "うちメモリ内（圧縮）"],
        "ram.ondisk": ["Moved to swap on disk", "Вынесено в swap на диск", "In Swap auf SSD ausgelagert", "Déplacé vers le swap", "Movido a swap en disco", "Movido para o swap em disco", "已移到磁盘交换文件", "ディスクのスワップへ退避"],
        "ram.ratio": ["Compression ratio", "Степень сжатия", "Kompressionsrate", "Taux de compression", "Ratio de compresión", "Taxa de compressão", "压缩比", "圧縮率"],

        // Disk
        "ssd.space": ["SPACE", "МЕСТО", "SPEICHERPLATZ", "ESPACE", "ESPACIO", "ESPAÇO", "空间", "容量"],
        "ssd.model": ["Drive", "Накопитель", "Laufwerk", "Disque", "Unidad", "Unidade", "硬盘", "ドライブ"],
        "ssd.capacity": ["Capacity", "Объём", "Kapazität", "Capacité", "Capacidad", "Capacidade", "容量", "容量"],
        "ssd.used": ["Used", "Занято", "Belegt", "Utilisé", "Usado", "Usado", "已用", "使用済み"],
        "ssd.free": ["Available", "Свободно", "Verfügbar", "Disponible", "Disponible", "Disponível", "可用", "空き"],
        "ssd.free.short": ["%@ free", "своб. %@", "%@ frei", "%@ libres", "%@ libres", "%@ livres", "可用 %@", "空き %@"],
        "ssd.swapfiles": ["Swap files on disk", "Файлы подкачки на диске", "Swap-Dateien auf SSD", "Fichiers d’échange sur disque", "Archivos de swap en disco", "Arquivos de swap no disco", "磁盘上的交换文件", "ディスク上のスワップファイル"],
        "ssd.files": ["%@ (%d files)", "%@ (файлов: %d)", "%@ (%d Dateien)", "%@ (%d fichiers)", "%@ (%d archivos)", "%@ (%d arquivos)", "%@（%d 个文件）", "%@（%d ファイル）"],
        "ssd.activity": ["ACTIVITY", "АКТИВНОСТЬ", "AKTIVITÄT", "ACTIVITÉ", "ACTIVIDAD", "ATIVIDADE", "活动", "アクティビティ"],
        "ssd.rnow": ["Reading now", "Чтение сейчас", "Liest jetzt", "Lecture actuelle", "Lectura ahora", "Lendo agora", "当前读取", "現在の読み出し"],
        "ssd.wnow": ["Writing now", "Запись сейчас", "Schreibt jetzt", "Écriture actuelle", "Escritura ahora", "Gravando agora", "当前写入", "現在の書き込み"],
        "ssd.wear": ["WRITTEN SINCE STARTUP (%@)", "ЗАПИСАНО С ВКЛЮЧЕНИЯ (%@)", "GESCHRIEBEN SEIT START (%@)", "ÉCRIT DEPUIS LE DÉMARRAGE (%@)", "ESCRITO DESDE EL ARRANQUE (%@)", "GRAVADO DESDE A INICIALIZAÇÃO (%@)", "开机以来写入（%@）", "起動後の書き込み（%@）"],
        "ssd.wtotal": ["Everything written to disk", "Всего записано на диск", "Insgesamt auf SSD geschrieben", "Total écrit sur le disque", "Total escrito en disco", "Total gravado no disco", "磁盘写入总量", "ディスクへの総書き込み"],
        "ssd.wswap": ["Of which swap", "Из них swap", "Davon Swap", "Dont swap", "De ello, swap", "Disso, swap", "其中交换", "うちスワップ"],
        "ssd.rtotal": ["Everything read from disk", "Всего прочитано с диска", "Insgesamt von SSD gelesen", "Total lu depuis le disque", "Total leído del disco", "Total lido do disco", "磁盘读取总量", "ディスクからの総読み出し"],

        // Swap detail
        "why.title": ["WHY SWAP IS IN USE", "ПОЧЕМУ SWAP ЗАНЯТ", "WARUM SWAP BELEGT IST", "POURQUOI LE SWAP EST UTILISÉ", "POR QUÉ SE USA SWAP", "POR QUE O SWAP É USADO", "为什么交换被占用", "スワップが使われる理由"],
        "why.1": ["When apps need more memory than is comfortable, macOS compresses data that hasn't been touched for a while. If that isn't enough, it moves the compressed data to swap files on the drive.", "Когда программам нужно больше памяти, чем комфортно системе, macOS сжимает данные, к которым давно не обращались. Если этого мало — переносит сжатые данные в файлы подкачки на накопителе.", "Brauchen Apps mehr Speicher als bequem verfügbar, komprimiert macOS länger ungenutzte Daten. Reicht das nicht, werden die komprimierten Daten in Swap-Dateien auf der SSD verschoben.", "Quand les apps demandent plus de mémoire que confortable, macOS compresse les données inutilisées depuis un moment. Si cela ne suffit pas, il les déplace vers des fichiers d’échange sur le disque.", "Cuando las apps necesitan más memoria de la cómoda, macOS comprime los datos que llevan un rato sin usarse. Si no basta, mueve los datos comprimidos a archivos de swap en el disco.", "Quando os apps precisam de mais memória do que o confortável, o macOS comprime dados que não são usados há algum tempo. Se não bastar, move os dados comprimidos para arquivos de swap no disco.", "当应用需要的内存超出舒适范围时，macOS 会压缩一段时间未访问的数据；如果仍不够，就把压缩数据移到磁盘上的交换文件。", "アプリが余裕以上のメモリを必要とすると、macOS はしばらく使われていないデータを圧縮します。それでも足りなければ、圧縮データをディスク上のスワップファイルへ移します。"],
        "why.2": ["Right now macOS holds %@ of compressed data: %@ in memory and %@ on disk.", "Сейчас у macOS %@ сжатых данных: %@ лежит в памяти и %@ — на диске.", "Derzeit hält macOS %@ komprimierte Daten: %@ im Speicher und %@ auf der SSD.", "macOS détient actuellement %@ de données compressées : %@ en mémoire et %@ sur disque.", "Ahora macOS mantiene %@ de datos comprimidos: %@ en memoria y %@ en disco.", "Agora o macOS mantém %@ de dados comprimidos: %@ na memória e %@ em disco.", "目前 macOS 共有 %@ 压缩数据：%@ 在内存中，%@ 在磁盘上。", "現在 macOS は %@ の圧縮データを保持しています：メモリ内 %@、ディスク上 %@。"],
        "why.3": ["The “%@ reserved” figure isn't a limit. macOS creates swap files in chunks as needed (%d files right now) and deletes them once they are no longer needed, so part of the reserved space is always empty.", "«Выделено %1$@» — это не предел. macOS создаёт файлы подкачки порциями по мере надобности (сейчас файлов: %2$d) и удаляет их, когда они больше не нужны, поэтому часть выделенного места всегда пустует.", "„%@ reserviert“ ist kein Limit. macOS legt Swap-Dateien stückweise nach Bedarf an (derzeit %d Dateien) und löscht sie wieder, wenn sie nicht mehr gebraucht werden – ein Teil des reservierten Platzes ist daher immer leer.", "« %@ réservés » n’est pas une limite. macOS crée les fichiers d’échange par blocs selon les besoins (%d fichiers actuellement) et les supprime ensuite ; une partie de l’espace réservé reste donc toujours vide.", "«%@ reservados» no es un límite. macOS crea archivos de swap por bloques según hace falta (%d archivos ahora) y los borra cuando ya no se necesitan, por eso parte del espacio reservado siempre está vacío.", "“%@ reservados” não é um limite. O macOS cria arquivos de swap em blocos conforme necessário (%d arquivos agora) e os apaga quando não são mais necessários; por isso parte do espaço reservado fica sempre vazia.", "“预留 %@”并不是上限。macOS 按需分块创建交换文件（目前 %d 个），不再需要时会删除，所以预留空间中总有一部分是空的。", "「確保済み %@」は上限ではありません。macOS は必要に応じてスワップファイルを分割して作成し（現在 %d 個）、不要になれば削除するため、確保分の一部は常に空いています。"],
        "why.4": ["Swap doesn't empty on its own when memory frees up: data stays on disk until its app asks for it again or quits. Occupied swap is not a problem by itself — what wears the SSD is new writes.", "Swap не очищается сам, когда память освобождается: данные остаются на диске, пока программа снова их не запросит или не будет закрыта. Сам по себе занятый swap не вреден — SSD изнашивает новая запись.", "Swap leert sich nicht von selbst, wenn Speicher frei wird: Daten bleiben auf der SSD, bis ihre App sie wieder braucht oder beendet wird. Belegter Swap ist kein Problem – neue Schreibvorgänge nutzen die SSD ab.", "Le swap ne se vide pas tout seul quand la mémoire se libère : les données restent sur disque jusqu’à ce que leur app les redemande ou se ferme. Un swap occupé n’est pas un problème en soi — ce sont les nouvelles écritures qui usent le SSD.", "El swap no se vacía solo cuando se libera memoria: los datos siguen en disco hasta que su app los pide de nuevo o se cierra. El swap ocupado no es un problema en sí; lo que desgasta el SSD son las nuevas escrituras.", "O swap não se esvazia sozinho quando a memória é liberada: os dados ficam em disco até o app pedi-los de novo ou ser encerrado. Swap ocupado não é problema em si — o que desgasta o SSD são novas gravações.", "内存释放后交换文件不会自动清空：数据会留在磁盘上，直到所属应用再次读取或退出。交换被占用本身不是问题——损耗 SSD 的是新的写入。", "メモリが空いてもスワップは自動では空になりません。アプリが再び読み込むか終了するまでデータはディスクに残ります。使用中であること自体は問題ではなく、SSD を消耗させるのは新たな書き込みです。"],
        "why.tip": ["To free swap, quit the apps at the top of the list on the main screen, or restart the Mac.", "Чтобы освободить swap, завершите программы из верхней части списка на главном экране или перезагрузите Mac.", "Um Swap freizugeben, beende die Apps oben in der Liste auf dem Hauptbildschirm oder starte den Mac neu.", "Pour libérer le swap, quittez les apps en tête de liste sur l’écran principal ou redémarrez le Mac.", "Para liberar swap, cierra las apps que encabezan la lista en la pantalla principal o reinicia el Mac.", "Para liberar swap, encerre os apps no topo da lista na tela principal ou reinicie o Mac.", "要释放交换空间，请退出主界面列表顶部的应用，或重新启动 Mac。", "スワップを解放するには、メイン画面のリスト上位のアプリを終了するか、Mac を再起動してください。"],
        "sw.writes": ["WRITES TO DISK", "ЗАПИСЬ НА ДИСК", "SCHREIBVORGÄNGE", "ÉCRITURES SUR DISQUE", "ESCRITURAS EN DISCO", "GRAVAÇÕES EM DISCO", "磁盘写入", "ディスクへの書き込み"],
        "sw.since": ["Written since startup (%@ ago)", "Записано с включения Mac (%@ назад)", "Seit dem Start geschrieben (vor %@)", "Écrit depuis le démarrage (il y a %@)", "Escrito desde el arranque (hace %@)", "Gravado desde a inicialização (há %@)", "开机以来写入（%@前）", "起動後の書き込み（%@前から）"],
        "sw.avg": ["Average per day", "В среднем за сутки", "Durchschnitt pro Tag", "Moyenne par jour", "Media por día", "Média por dia", "日均", "1日平均"],
        "sw.rsince": ["Read back since startup", "Прочитано обратно с включения", "Seit dem Start zurückgelesen", "Relu depuis le démarrage", "Leído de vuelta desde el arranque", "Lido de volta desde a inicialização", "开机以来读回", "起動後の読み戻し"],
        "sw.rnow": ["Reading now", "Чтение сейчас", "Liest jetzt", "Lecture actuelle", "Lectura ahora", "Lendo agora", "当前读取", "現在の読み出し"],
        "sw.state": ["RIGHT NOW", "СЕЙЧАС", "AKTUELL", "EN CE MOMENT", "AHORA", "AGORA", "当前状态", "現在"],
        "sw.used": ["Occupied", "Занято", "Belegt", "Occupé", "Ocupado", "Ocupado", "已占用", "使用中"],
        "sw.reserved": ["Reserved by macOS", "Выделено macOS", "Von macOS reserviert", "Réservé par macOS", "Reservado por macOS", "Reservado pelo macOS", "macOS 已预留", "macOS が確保"],
        "tip.swap": ["Swap: %@ of %@", "Swap: %@ из %@", "Swap: %@ von %@", "Swap : %@ sur %@", "Swap: %@ de %@", "Swap: %@ de %@", "交换：%@ / %@", "スワップ：%@ / %@"],

        // Widget
        "w.name": ["Swap monitor", "Монитор swap", "Swap-Monitor", "Moniteur de swap", "Monitor de swap", "Monitor de swap", "交换监视器", "スワップモニタ"],
        "w.desc": ["Swap usage, memory and writes to disk.", "Занятый swap, память и запись на диск.", "Swap-Belegung, Speicher und Schreibvorgänge.", "Swap utilisé, mémoire et écritures sur disque.", "Uso de swap, memoria y escrituras en disco.", "Uso de swap, memória e gravações em disco.", "交换占用、内存和磁盘写入。", "スワップ使用量、メモリ、ディスク書き込み。"],
        "w.swap": ["Swap", "Swap", "Swap", "Swap", "Swap", "Swap", "交换", "スワップ"],
        "w.written": ["Written", "Записано", "Geschrieben", "Écrit", "Escrito", "Gravado", "已写入", "書き込み"],
    ]
}
