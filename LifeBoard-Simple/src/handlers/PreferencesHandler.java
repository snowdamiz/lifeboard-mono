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
 * Preferences Handler
 * 
 * Manages user preferences and settings.
 * 
 * Endpoints:
 * GET /api/preferences - Get user preferences
 * PUT /api/preferences - Update user preferences
 */
public class PreferencesHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();

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

            if (method.equals("GET")) {
                getPreferences(exchange, userId);
            } else if (method.equals("PUT")) {
                updatePreferences(exchange, userId);
            } else {
                Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
            }

        } catch (SQLException e) {
            e.printStackTrace();
            Main.sendJson(exchange, 500, "{\"error\":\"Database error\"}");
        }
    }

    private void getPreferences(HttpExchange exchange, long userId) throws IOException, SQLException {
        try (ResultSet rs = Database.query(
                "SELECT * FROM user_preferences WHERE user_id = ?", userId)) {
            if (rs.next()) {
                String response = JsonUtil.object()
                        .put("theme", rs.getString("theme"))
                        .put("sidebarCollapsed", rs.getInt("sidebar_collapsed") == 1)
                        .put("defaultCalendarView", rs.getString("default_calendar_view"))
                        .put("weekStartsOn", rs.getInt("week_starts_on"))
                        .put("timeFormat", rs.getString("time_format"))
                        .put("dateFormat", rs.getString("date_format"))
                        .toString();

                Main.sendJson(exchange, 200, response);
            } else {
                // Create default preferences
                Database.insert(
                        "INSERT INTO user_preferences (user_id) VALUES (?)",
                        userId);

                String response = JsonUtil.object()
                        .put("theme", "system")
                        .put("sidebarCollapsed", false)
                        .put("defaultCalendarView", "week")
                        .put("weekStartsOn", 0)
                        .put("timeFormat", "12h")
                        .put("dateFormat", "MM/DD/YYYY")
                        .toString();

                Main.sendJson(exchange, 200, response);
            }
        }
    }

    private void updatePreferences(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE user_preferences SET user_id = user_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("theme")) {
            sql.append(", theme = ?");
            params.add(data.get("theme"));
        }
        if (data.containsKey("sidebarCollapsed")) {
            sql.append(", sidebar_collapsed = ?");
            params.add(Boolean.TRUE.equals(data.get("sidebarCollapsed")) ? 1 : 0);
        }
        if (data.containsKey("defaultCalendarView")) {
            sql.append(", default_calendar_view = ?");
            params.add(data.get("defaultCalendarView"));
        }
        if (data.containsKey("weekStartsOn")) {
            sql.append(", week_starts_on = ?");
            params.add(data.get("weekStartsOn"));
        }
        if (data.containsKey("timeFormat")) {
            sql.append(", time_format = ?");
            params.add(data.get("timeFormat"));
        }
        if (data.containsKey("dateFormat")) {
            sql.append(", date_format = ?");
            params.add(data.get("dateFormat"));
        }

        sql.append(" WHERE user_id = ?");
        params.add(userId);

        int updated = Database.update(sql.toString(), params.toArray());

        if (updated == 0) {
            // Preferences don't exist yet, create them
            Database.insert(
                    "INSERT INTO user_preferences (user_id, theme, sidebar_collapsed, default_calendar_view, week_starts_on, time_format, date_format) "
                            +
                            "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    userId,
                    data.getOrDefault("theme", "system"),
                    Boolean.TRUE.equals(data.get("sidebarCollapsed")) ? 1 : 0,
                    data.getOrDefault("defaultCalendarView", "week"),
                    data.getOrDefault("weekStartsOn", 0),
                    data.getOrDefault("timeFormat", "12h"),
                    data.getOrDefault("dateFormat", "MM/DD/YYYY"));
        }

        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void handleCors(HttpExchange exchange) throws IOException {
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, PUT, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");
        exchange.sendResponseHeaders(204, -1);
    }
}
