package lifeboard;

import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import lifeboard.handlers.*;
import lifeboard.db.Database;

import java.io.*;
import java.net.InetSocketAddress;
import java.nio.file.*;

/**
 * LifeBoard Main Server
 * 
 * A simple, human-readable HTTP server for the LifeBoard personal planning app.
 * Uses Java's built-in HttpServer - no external frameworks required.
 * 
 * Start with: java -cp "lib/*;." lifeboard.Main
 * Then open: http://localhost:8080
 */
public class Main {

    private static final int PORT = 8080;
    private static final String WEB_ROOT = "web";

    public static void main(String[] args) throws Exception {
        // Initialize database
        System.out.println("Initializing database...");
        Database.initialize();

        // Create HTTP server
        HttpServer server = HttpServer.create(new InetSocketAddress(PORT), 0);

        // Static file serving for web assets
        server.createContext("/", new StaticFileHandler());

        // API endpoints
        server.createContext("/api/health", exchange -> {
            sendJson(exchange, 200, "{\"status\":\"ok\"}");
        });

        // Authentication
        server.createContext("/api/login", new AuthHandler());
        server.createContext("/api/logout", new AuthHandler());
        server.createContext("/api/register", new AuthHandler());
        server.createContext("/api/me", new AuthHandler());

        // Tasks
        server.createContext("/api/tasks", new TaskHandler());

        // Inventory
        server.createContext("/api/inventory", new InventoryHandler());

        // Shopping Lists
        server.createContext("/api/shopping-lists", new ShoppingHandler());

        // Budget
        server.createContext("/api/budget", new BudgetHandler());

        // Notes
        server.createContext("/api/notebooks", new NotesHandler());
        server.createContext("/api/pages", new NotesHandler());

        // Goals
        server.createContext("/api/goals", new GoalsHandler());
        server.createContext("/api/goal-categories", new GoalsHandler());

        // Habits
        server.createContext("/api/habits", new HabitsHandler());

        // Tags
        server.createContext("/api/tags", new TagsHandler());

        // Notifications
        server.createContext("/api/notifications", new NotificationsHandler());

        // Preferences
        server.createContext("/api/preferences", new PreferencesHandler());

        // Start server
        server.setExecutor(null); // Use default executor
        server.start();

        System.out.println("========================================");
        System.out.println("  LifeBoard Server Started!");
        System.out.println("  Open: http://localhost:" + PORT);
        System.out.println("  Press Ctrl+C to stop");
        System.out.println("========================================");
    }

    /**
     * Send a JSON response
     */
    public static void sendJson(HttpExchange exchange, int status, String json) throws IOException {
        // Add CORS headers
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");

        byte[] response = json.getBytes("UTF-8");
        exchange.sendResponseHeaders(status, response.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(response);
        }
    }

    /**
     * Read request body as string
     */
    public static String readBody(HttpExchange exchange) throws IOException {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(exchange.getRequestBody(), "UTF-8"))) {
            StringBuilder body = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                body.append(line);
            }
            return body.toString();
        }
    }

    /**
     * Static file handler for serving HTML, CSS, JS files
     */
    static class StaticFileHandler implements HttpHandler {

        @Override
        public void handle(HttpExchange exchange) throws IOException {
            String path = exchange.getRequestURI().getPath();

            // Default to index.html
            if (path.equals("/") || path.equals("")) {
                path = "/index.html";
            }

            // Resolve file path
            Path filePath = Paths.get(WEB_ROOT + path);

            if (Files.exists(filePath) && !Files.isDirectory(filePath)) {
                // Serve the file
                String contentType = getContentType(path);
                byte[] content = Files.readAllBytes(filePath);

                exchange.getResponseHeaders().add("Content-Type", contentType);
                exchange.sendResponseHeaders(200, content.length);
                try (OutputStream os = exchange.getResponseBody()) {
                    os.write(content);
                }
            } else {
                // 404 Not Found
                String response = "File not found: " + path;
                exchange.sendResponseHeaders(404, response.length());
                try (OutputStream os = exchange.getResponseBody()) {
                    os.write(response.getBytes());
                }
            }
        }

        private String getContentType(String path) {
            if (path.endsWith(".html"))
                return "text/html; charset=UTF-8";
            if (path.endsWith(".css"))
                return "text/css; charset=UTF-8";
            if (path.endsWith(".js"))
                return "application/javascript; charset=UTF-8";
            if (path.endsWith(".json"))
                return "application/json; charset=UTF-8";
            if (path.endsWith(".png"))
                return "image/png";
            if (path.endsWith(".jpg") || path.endsWith(".jpeg"))
                return "image/jpeg";
            if (path.endsWith(".svg"))
                return "image/svg+xml";
            if (path.endsWith(".ico"))
                return "image/x-icon";
            return "application/octet-stream";
        }
    }
}
