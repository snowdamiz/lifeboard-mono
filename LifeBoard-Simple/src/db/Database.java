package lifeboard.db;

import java.sql.*;
import java.io.File;

/**
 * Database Manager for LifeBoard
 * 
 * Uses SQLite for simple, file-based storage.
 * All data is stored in: data/lifeboard.db
 * 
 * This class handles:
 * - Database connection
 * - Schema initialization
 * - Common query helpers
 */
public class Database {

    private static final String DB_PATH = "data/lifeboard.db";
    private static Connection connection;

    /**
     * Initialize the database and create tables if they don't exist
     */
    public static void initialize() throws SQLException {
        // Ensure data directory exists
        new File("data").mkdirs();

        // Explicitly load the SQLite JDBC driver
        try {
            Class.forName("org.sqlite.JDBC");
        } catch (ClassNotFoundException e) {
            throw new SQLException("SQLite JDBC driver not found. Make sure sqlite-jdbc.jar is in the lib folder.", e);
        }

        // Connect to SQLite database (creates file if doesn't exist)
        connection = DriverManager.getConnection("jdbc:sqlite:" + DB_PATH);

        System.out.println("Connected to database: " + DB_PATH);

        // Create all tables
        createTables();
    }

    /**
     * Get the database connection
     */
    public static Connection getConnection() {
        return connection;
    }

    /**
     * Create all database tables
     */
    private static void createTables() throws SQLException {
        try (Statement stmt = connection.createStatement()) {

            // ============================================================
            // USERS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS users (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            username TEXT UNIQUE NOT NULL,
                            password_hash TEXT NOT NULL,
                            display_name TEXT,
                            email TEXT,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                        )
                    """);

            // ============================================================
            // TAGS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS tags (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            color TEXT DEFAULT '#3B82F6',
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                            UNIQUE(user_id, name)
                        )
                    """);

            // ============================================================
            // TASKS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS tasks (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            title TEXT NOT NULL,
                            description TEXT,
                            status TEXT DEFAULT 'pending',
                            priority INTEGER DEFAULT 2,
                            due_date DATE,
                            due_time TIME,
                            duration_minutes INTEGER,
                            completed_at DATETIME,
                            sort_order INTEGER DEFAULT 0,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // TASK STEPS TABLE (checklist items within a task)
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS task_steps (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            task_id INTEGER NOT NULL,
                            title TEXT NOT NULL,
                            completed INTEGER DEFAULT 0,
                            sort_order INTEGER DEFAULT 0,
                            FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // TASK-TAG JUNCTION TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS task_tags (
                            task_id INTEGER NOT NULL,
                            tag_id INTEGER NOT NULL,
                            PRIMARY KEY (task_id, tag_id),
                            FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
                            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // TASK TEMPLATES TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS task_templates (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            description TEXT,
                            template_data TEXT,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // INVENTORY SHEETS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS inventory_sheets (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            description TEXT,
                            icon TEXT DEFAULT '📦',
                            color TEXT DEFAULT '#3B82F6',
                            sort_order INTEGER DEFAULT 0,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // INVENTORY ITEMS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS inventory_items (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            sheet_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            description TEXT,
                            quantity INTEGER DEFAULT 0,
                            min_quantity INTEGER DEFAULT 0,
                            unit TEXT,
                            is_essential INTEGER DEFAULT 0,
                            last_restocked DATETIME,
                            notes TEXT,
                            sort_order INTEGER DEFAULT 0,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (sheet_id) REFERENCES inventory_sheets(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // SHOPPING LISTS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS shopping_lists (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            status TEXT DEFAULT 'active',
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            completed_at DATETIME,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // SHOPPING LIST ITEMS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS shopping_list_items (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            list_id INTEGER NOT NULL,
                            inventory_item_id INTEGER,
                            name TEXT NOT NULL,
                            quantity INTEGER DEFAULT 1,
                            checked INTEGER DEFAULT 0,
                            sort_order INTEGER DEFAULT 0,
                            FOREIGN KEY (list_id) REFERENCES shopping_lists(id) ON DELETE CASCADE,
                            FOREIGN KEY (inventory_item_id) REFERENCES inventory_items(id) ON DELETE SET NULL
                        )
                    """);

            // ============================================================
            // BUDGET SOURCES TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS budget_sources (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            type TEXT NOT NULL,
                            amount REAL DEFAULT 0,
                            frequency TEXT DEFAULT 'monthly',
                            color TEXT DEFAULT '#10B981',
                            icon TEXT DEFAULT '💰',
                            is_active INTEGER DEFAULT 1,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // BUDGET ENTRIES TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS budget_entries (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            source_id INTEGER NOT NULL,
                            amount REAL NOT NULL,
                            date DATE NOT NULL,
                            description TEXT,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (source_id) REFERENCES budget_sources(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // NOTEBOOKS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS notebooks (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            description TEXT,
                            color TEXT DEFAULT '#8B5CF6',
                            icon TEXT DEFAULT '📓',
                            is_pinned INTEGER DEFAULT 0,
                            sort_order INTEGER DEFAULT 0,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // PAGES TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS pages (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            notebook_id INTEGER NOT NULL,
                            title TEXT NOT NULL,
                            content TEXT,
                            is_pinned INTEGER DEFAULT 0,
                            sort_order INTEGER DEFAULT 0,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (notebook_id) REFERENCES notebooks(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // GOAL CATEGORIES TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS goal_categories (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            color TEXT DEFAULT '#F59E0B',
                            icon TEXT DEFAULT '🎯',
                            sort_order INTEGER DEFAULT 0,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // GOALS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS goals (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            category_id INTEGER,
                            title TEXT NOT NULL,
                            description TEXT,
                            status TEXT DEFAULT 'active',
                            priority INTEGER DEFAULT 2,
                            target_date DATE,
                            progress INTEGER DEFAULT 0,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            completed_at DATETIME,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                            FOREIGN KEY (category_id) REFERENCES goal_categories(id) ON DELETE SET NULL
                        )
                    """);

            // ============================================================
            // GOAL MILESTONES TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS goal_milestones (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            goal_id INTEGER NOT NULL,
                            title TEXT NOT NULL,
                            description TEXT,
                            completed INTEGER DEFAULT 0,
                            target_date DATE,
                            completed_at DATETIME,
                            sort_order INTEGER DEFAULT 0,
                            FOREIGN KEY (goal_id) REFERENCES goals(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // HABITS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS habits (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            name TEXT NOT NULL,
                            description TEXT,
                            frequency TEXT DEFAULT 'daily',
                            target_count INTEGER DEFAULT 1,
                            color TEXT DEFAULT '#EC4899',
                            icon TEXT DEFAULT '✅',
                            is_active INTEGER DEFAULT 1,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // HABIT COMPLETIONS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS habit_completions (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            habit_id INTEGER NOT NULL,
                            completed_date DATE NOT NULL,
                            count INTEGER DEFAULT 1,
                            notes TEXT,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
                            UNIQUE(habit_id, completed_date)
                        )
                    """);

            // ============================================================
            // NOTIFICATIONS TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS notifications (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            type TEXT NOT NULL,
                            title TEXT NOT NULL,
                            message TEXT,
                            link TEXT,
                            is_read INTEGER DEFAULT 0,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // USER PREFERENCES TABLE
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS user_preferences (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER UNIQUE NOT NULL,
                            theme TEXT DEFAULT 'system',
                            sidebar_collapsed INTEGER DEFAULT 0,
                            default_calendar_view TEXT DEFAULT 'week',
                            week_starts_on INTEGER DEFAULT 0,
                            time_format TEXT DEFAULT '12h',
                            date_format TEXT DEFAULT 'MM/DD/YYYY',
                            preferences_json TEXT DEFAULT '{}',
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            // ============================================================
            // SESSIONS TABLE (for auth)
            // ============================================================
            stmt.execute("""
                        CREATE TABLE IF NOT EXISTS sessions (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            user_id INTEGER NOT NULL,
                            token TEXT UNIQUE NOT NULL,
                            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                            expires_at DATETIME NOT NULL,
                            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                        )
                    """);

            System.out.println("Database tables created successfully.");
        }
    }

    /**
     * Helper: Execute a query and return results
     */
    public static ResultSet query(String sql, Object... params) throws SQLException {
        PreparedStatement stmt = connection.prepareStatement(sql);
        for (int i = 0; i < params.length; i++) {
            stmt.setObject(i + 1, params[i]);
        }
        return stmt.executeQuery();
    }

    /**
     * Helper: Execute an update (INSERT, UPDATE, DELETE)
     */
    public static int update(String sql, Object... params) throws SQLException {
        try (PreparedStatement stmt = connection.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) {
                stmt.setObject(i + 1, params[i]);
            }
            return stmt.executeUpdate();
        }
    }

    /**
     * Helper: Insert and return generated ID
     */
    public static long insert(String sql, Object... params) throws SQLException {
        try (PreparedStatement stmt = connection.prepareStatement(sql,
                Statement.RETURN_GENERATED_KEYS)) {
            for (int i = 0; i < params.length; i++) {
                stmt.setObject(i + 1, params[i]);
            }
            stmt.executeUpdate();

            try (ResultSet keys = stmt.getGeneratedKeys()) {
                if (keys.next()) {
                    return keys.getLong(1);
                }
            }
            return -1;
        }
    }

    /**
     * Close the database connection
     */
    public static void close() {
        try {
            if (connection != null && !connection.isClosed()) {
                connection.close();
                System.out.println("Database connection closed.");
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}
