package lifeboard.handlers;

import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import lifeboard.db.Database;
import lifeboard.util.JsonUtil;
import lifeboard.util.SessionUtil;
import lifeboard.Main;

import java.io.*;
import java.sql.*;
import java.util.*;

/**
 * Authentication Handler
 * 
 * Handles user login, logout, registration, and session management.
 * 
 * Endpoints:
 * POST /api/login - Login with username/password
 * POST /api/logout - Logout current session
 * GET /api/me - Get current user info
 * POST /api/register - Create new account
 */
public class AuthHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();

        // Handle CORS preflight
        if (method.equals("OPTIONS")) {
            handleCors(exchange);
            return;
        }

        try {
            // Route to appropriate handler
            if (path.equals("/api/login") && method.equals("POST")) {
                handleLogin(exchange);
            } else if (path.equals("/api/logout") && method.equals("POST")) {
                handleLogout(exchange);
            } else if (path.equals("/api/me") && method.equals("GET")) {
                handleMe(exchange);
            } else if (path.equals("/api/register") && method.equals("POST")) {
                handleRegister(exchange);
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Not found\"}");
            }
        } catch (SQLException e) {
            e.printStackTrace();
            Main.sendJson(exchange, 500, "{\"error\":\"Database error\"}");
        }
    }

    /**
     * POST /api/login
     * Body: {"username": "...", "password": "..."}
     */
    private void handleLogin(HttpExchange exchange) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String username = (String) data.get("username");
        String password = (String) data.get("password");

        if (username == null || password == null) {
            Main.sendJson(exchange, 400, "{\"error\":\"Username and password required\"}");
            return;
        }

        // Find user
        try (ResultSet rs = Database.query(
                "SELECT id, password_hash, display_name FROM users WHERE username = ?",
                username)) {
            if (rs.next()) {
                String hash = rs.getString("password_hash");
                if (SessionUtil.verifyPassword(password, hash)) {
                    // Create session
                    long userId = rs.getLong("id");
                    String token = SessionUtil.createSession(userId);
                    String displayName = rs.getString("display_name");

                    String response = JsonUtil.object()
                            .put("token", token)
                            .put("user", JsonUtil.object()
                                    .put("id", userId)
                                    .put("username", username)
                                    .put("displayName", displayName))
                            .toString();

                    Main.sendJson(exchange, 200, response);
                    return;
                }
            }
        }

        Main.sendJson(exchange, 401, "{\"error\":\"Invalid username or password\"}");
    }

    /**
     * POST /api/logout
     */
    private void handleLogout(HttpExchange exchange) throws IOException, SQLException {
        String authHeader = exchange.getRequestHeaders().getFirst("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            SessionUtil.deleteSession(token);
        }
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    /**
     * GET /api/me
     * Returns current user info
     */
    private void handleMe(HttpExchange exchange) throws IOException, SQLException {
        long userId = SessionUtil.getUserIdFromRequest(exchange);

        if (userId < 0) {
            Main.sendJson(exchange, 401, "{\"error\":\"Not authenticated\"}");
            return;
        }

        try (ResultSet rs = Database.query(
                "SELECT id, username, display_name, email, created_at FROM users WHERE id = ?",
                userId)) {
            if (rs.next()) {
                String response = JsonUtil.object()
                        .put("id", rs.getLong("id"))
                        .put("username", rs.getString("username"))
                        .put("displayName", rs.getString("display_name"))
                        .put("email", rs.getString("email"))
                        .put("createdAt", rs.getString("created_at"))
                        .toString();

                Main.sendJson(exchange, 200, response);
                return;
            }
        }

        Main.sendJson(exchange, 404, "{\"error\":\"User not found\"}");
    }

    /**
     * POST /api/register
     * Body: {"username": "...", "password": "...", "displayName": "..."}
     */
    private void handleRegister(HttpExchange exchange) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String username = (String) data.get("username");
        String password = (String) data.get("password");
        String displayName = (String) data.get("displayName");
        String email = (String) data.get("email");

        if (username == null || password == null) {
            Main.sendJson(exchange, 400, "{\"error\":\"Username and password required\"}");
            return;
        }

        // Check if username exists
        try (ResultSet rs = Database.query(
                "SELECT id FROM users WHERE username = ?", username)) {
            if (rs.next()) {
                Main.sendJson(exchange, 409, "{\"error\":\"Username already exists\"}");
                return;
            }
        }

        // Create user
        String passwordHash = SessionUtil.hashPassword(password);
        long userId = Database.insert(
                "INSERT INTO users (username, password_hash, display_name, email) VALUES (?, ?, ?, ?)",
                username, passwordHash, displayName != null ? displayName : username, email);

        // Create default preferences
        Database.insert(
                "INSERT INTO user_preferences (user_id) VALUES (?)",
                userId);

        // Create session
        String token = SessionUtil.createSession(userId);

        String response = JsonUtil.object()
                .put("token", token)
                .put("user", JsonUtil.object()
                        .put("id", userId)
                        .put("username", username)
                        .put("displayName", displayName != null ? displayName : username))
                .toString();

        Main.sendJson(exchange, 201, response);
    }

    private void handleCors(HttpExchange exchange) throws IOException {
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");
        exchange.sendResponseHeaders(204, -1);
    }
}
