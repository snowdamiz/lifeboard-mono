package lifeboard.handlers;

import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import lifeboard.db.Database;
import lifeboard.util.JsonUtil;
import lifeboard.util.JsonUtil.JsonArray;
import lifeboard.util.SessionUtil;
import lifeboard.Main;

import java.io.*;
import java.sql.*;
import java.util.*;

/**
 * Notifications Handler
 * 
 * Manages user notifications.
 * 
 * Endpoints:
 * GET /api/notifications - List notifications
 * GET /api/notifications/unread-count - Get unread count
 * PUT /api/notifications/{id}/read - Mark as read
 * POST /api/notifications/mark-all-read - Mark all as read
 * DELETE /api/notifications/{id} - Delete notification
 */
public class NotificationsHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();

        if (method.equals("OPTIONS")) {
            handleCors(exchange);
            return;
        }

        try {
            long userId = SessionUtil.getUserIdFromRequest(exchange);
            if (userId < 0) {
                Main.sendJson(exchange, 401, "{\"error\":\"Not authenticated\"}");
                return;
            }

            String[] parts = path.split("/");

            if (parts.length == 3 && method.equals("GET")) {
                listNotifications(exchange, userId);
            } else if (parts.length == 4) {
                if (parts[3].equals("unread-count") && method.equals("GET")) {
                    getUnreadCount(exchange, userId);
                } else if (parts[3].equals("mark-all-read") && method.equals("POST")) {
                    markAllRead(exchange, userId);
                } else {
                    long notifId = Long.parseLong(parts[3]);
                    if (method.equals("DELETE")) {
                        deleteNotification(exchange, userId, notifId);
                    } else {
                        Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    }
                }
            } else if (parts.length == 5 && parts[4].equals("read") && method.equals("PUT")) {
                long notifId = Long.parseLong(parts[3]);
                markRead(exchange, userId, notifId);
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Not found\"}");
            }

        } catch (NumberFormatException e) {
            Main.sendJson(exchange, 400, "{\"error\":\"Invalid ID format\"}");
        } catch (SQLException e) {
            e.printStackTrace();
            Main.sendJson(exchange, 500, "{\"error\":\"Database error\"}");
        }
    }

    private void listNotifications(HttpExchange exchange, long userId) throws IOException, SQLException {
        JsonArray notifications = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50",
                userId)) {
            while (rs.next()) {
                notifications.add(JsonUtil.object()
                        .put("id", rs.getLong("id"))
                        .put("type", rs.getString("type"))
                        .put("title", rs.getString("title"))
                        .put("message", rs.getString("message"))
                        .put("link", rs.getString("link"))
                        .put("isRead", rs.getInt("is_read") == 1)
                        .put("createdAt", rs.getString("created_at")));
            }
        }

        Main.sendJson(exchange, 200, notifications.toString());
    }

    private void getUnreadCount(HttpExchange exchange, long userId) throws IOException, SQLException {
        try (ResultSet rs = Database.query(
                "SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0",
                userId)) {
            int count = rs.next() ? rs.getInt("count") : 0;
            Main.sendJson(exchange, 200, "{\"count\":" + count + "}");
        }
    }

    private void markRead(HttpExchange exchange, long userId, long notifId) throws IOException, SQLException {
        Database.update(
                "UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?",
                notifId, userId);
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void markAllRead(HttpExchange exchange, long userId) throws IOException, SQLException {
        Database.update(
                "UPDATE notifications SET is_read = 1 WHERE user_id = ?",
                userId);
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteNotification(HttpExchange exchange, long userId, long notifId) throws IOException, SQLException {
        Database.update(
                "DELETE FROM notifications WHERE id = ? AND user_id = ?",
                notifId, userId);
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void handleCors(HttpExchange exchange) throws IOException {
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");
        exchange.sendResponseHeaders(204, -1);
    }
}
