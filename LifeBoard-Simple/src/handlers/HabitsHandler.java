package lifeboard.handlers;

import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import lifeboard.db.Database;
import lifeboard.util.JsonUtil;
import lifeboard.util.JsonUtil.JsonObject;
import lifeboard.util.JsonUtil.JsonArray;
import lifeboard.util.SessionUtil;
import lifeboard.Main;

import java.io.*;
import java.sql.*;
import java.util.*;

/**
 * Habits Handler
 * 
 * Manages habits and their completions.
 * 
 * Endpoints:
 * GET /api/habits - List all habits
 * POST /api/habits - Create a habit
 * GET /api/habits/{id} - Get a habit
 * PUT /api/habits/{id} - Update a habit
 * DELETE /api/habits/{id} - Delete a habit
 * POST /api/habits/{id}/complete - Mark habit as complete for today
 * DELETE /api/habits/{id}/complete - Unmark habit completion
 * GET /api/habits/{id}/completions - Get completion history
 */
public class HabitsHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();
        String query = exchange.getRequestURI().getQuery();

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

            if (parts.length == 3) {
                if (method.equals("GET"))
                    listHabits(exchange, userId, query);
                else if (method.equals("POST"))
                    createHabit(exchange, userId);
                else
                    Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
            } else if (parts.length == 4) {
                long habitId = Long.parseLong(parts[3]);
                if (method.equals("GET"))
                    getHabit(exchange, userId, habitId);
                else if (method.equals("PUT"))
                    updateHabit(exchange, userId, habitId);
                else if (method.equals("DELETE"))
                    deleteHabit(exchange, userId, habitId);
                else
                    Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
            } else if (parts.length == 5) {
                long habitId = Long.parseLong(parts[3]);
                if (parts[4].equals("complete")) {
                    if (method.equals("POST"))
                        completeHabit(exchange, userId, habitId);
                    else if (method.equals("DELETE"))
                        uncompleteHabit(exchange, userId, habitId);
                    else
                        Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                } else if (parts[4].equals("completions") && method.equals("GET")) {
                    getCompletions(exchange, userId, habitId, query);
                } else {
                    Main.sendJson(exchange, 404, "{\"error\":\"Not found\"}");
                }
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

    private void listHabits(HttpExchange exchange, long userId, String query) throws IOException, SQLException {
        Map<String, String> params = parseQuery(query);
        String date = params.getOrDefault("date",
                new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()));

        JsonArray habits = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT h.*, " +
                        "(SELECT COUNT(*) FROM habit_completions WHERE habit_id = h.id AND completed_date = ?) as completed_today, "
                        +
                        "(SELECT COUNT(*) FROM habit_completions WHERE habit_id = h.id) as total_completions " +
                        "FROM habits h WHERE user_id = ? AND is_active = 1 ORDER BY name",
                date, userId)) {
            while (rs.next()) {
                habits.add(habitToJson(rs));
            }
        }

        Main.sendJson(exchange, 200, habits.toString());
    }

    private void createHabit(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String name = (String) data.get("name");
        if (name == null || name.trim().isEmpty()) {
            Main.sendJson(exchange, 400, "{\"error\":\"Name is required\"}");
            return;
        }

        long habitId = Database.insert(
                "INSERT INTO habits (user_id, name, description, frequency, target_count, color, icon) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?)",
                userId, name, data.get("description"),
                data.getOrDefault("frequency", "daily"),
                data.getOrDefault("targetCount", 1),
                data.getOrDefault("color", "#EC4899"),
                data.getOrDefault("icon", "✅"));

        try (ResultSet rs = Database.query(
                "SELECT *, 0 as completed_today, 0 as total_completions FROM habits WHERE id = ?",
                habitId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, habitToJson(rs).toString());
            }
        }
    }

    private void getHabit(HttpExchange exchange, long userId, long habitId) throws IOException, SQLException {
        String date = new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date());

        try (ResultSet rs = Database.query(
                "SELECT h.*, " +
                        "(SELECT COUNT(*) FROM habit_completions WHERE habit_id = h.id AND completed_date = ?) as completed_today, "
                        +
                        "(SELECT COUNT(*) FROM habit_completions WHERE habit_id = h.id) as total_completions " +
                        "FROM habits h WHERE id = ? AND user_id = ?",
                date, habitId, userId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 200, habitToJson(rs).toString());
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Habit not found\"}");
            }
        }
    }

    private void updateHabit(HttpExchange exchange, long userId, long habitId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE habits SET user_id = user_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("description")) {
            sql.append(", description = ?");
            params.add(data.get("description"));
        }
        if (data.containsKey("frequency")) {
            sql.append(", frequency = ?");
            params.add(data.get("frequency"));
        }
        if (data.containsKey("targetCount")) {
            sql.append(", target_count = ?");
            params.add(data.get("targetCount"));
        }
        if (data.containsKey("color")) {
            sql.append(", color = ?");
            params.add(data.get("color"));
        }
        if (data.containsKey("icon")) {
            sql.append(", icon = ?");
            params.add(data.get("icon"));
        }
        if (data.containsKey("isActive")) {
            sql.append(", is_active = ?");
            params.add(Boolean.TRUE.equals(data.get("isActive")) ? 1 : 0);
        }

        sql.append(" WHERE id = ? AND user_id = ?");
        params.add(habitId);
        params.add(userId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteHabit(HttpExchange exchange, long userId, long habitId) throws IOException, SQLException {
        Database.update("DELETE FROM habits WHERE id = ? AND user_id = ?", habitId, userId);
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void completeHabit(HttpExchange exchange, long userId, long habitId) throws IOException, SQLException {
        if (!verifyOwnership(habitId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Habit not found\"}");
            return;
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String date = (String) data.getOrDefault("date",
                new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date()));

        // Check if already completed today
        try (ResultSet rs = Database.query(
                "SELECT id FROM habit_completions WHERE habit_id = ? AND completed_date = ?",
                habitId, date)) {
            if (rs.next()) {
                // Already completed, maybe increment count
                Database.update(
                        "UPDATE habit_completions SET count = count + 1 WHERE habit_id = ? AND completed_date = ?",
                        habitId, date);
            } else {
                // New completion
                Database.insert(
                        "INSERT INTO habit_completions (habit_id, completed_date, notes) VALUES (?, ?, ?)",
                        habitId, date, data.get("notes"));
            }
        }

        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void uncompleteHabit(HttpExchange exchange, long userId, long habitId) throws IOException, SQLException {
        if (!verifyOwnership(habitId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Habit not found\"}");
            return;
        }

        String date = new java.text.SimpleDateFormat("yyyy-MM-dd").format(new java.util.Date());

        // Parse date from query if provided
        String query = exchange.getRequestURI().getQuery();
        if (query != null) {
            Map<String, String> params = parseQuery(query);
            date = params.getOrDefault("date", date);
        }

        Database.update(
                "DELETE FROM habit_completions WHERE habit_id = ? AND completed_date = ?",
                habitId, date);

        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void getCompletions(HttpExchange exchange, long userId, long habitId, String query)
            throws IOException, SQLException {
        if (!verifyOwnership(habitId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Habit not found\"}");
            return;
        }

        Map<String, String> params = parseQuery(query);

        StringBuilder sql = new StringBuilder(
                "SELECT * FROM habit_completions WHERE habit_id = ? ");
        List<Object> sqlParams = new ArrayList<>();
        sqlParams.add(habitId);

        if (params.containsKey("startDate") && params.containsKey("endDate")) {
            sql.append("AND completed_date BETWEEN ? AND ? ");
            sqlParams.add(params.get("startDate"));
            sqlParams.add(params.get("endDate"));
        }

        sql.append("ORDER BY completed_date DESC LIMIT 100");

        JsonArray completions = JsonUtil.array();
        try (ResultSet rs = Database.query(sql.toString(), sqlParams.toArray())) {
            while (rs.next()) {
                completions.add(JsonUtil.object()
                        .put("id", rs.getLong("id"))
                        .put("completedDate", rs.getString("completed_date"))
                        .put("count", rs.getInt("count"))
                        .put("notes", rs.getString("notes")));
            }
        }

        Main.sendJson(exchange, 200, completions.toString());
    }

    private JsonObject habitToJson(ResultSet rs) throws SQLException {
        return JsonUtil.object()
                .put("id", rs.getLong("id"))
                .put("name", rs.getString("name"))
                .put("description", rs.getString("description"))
                .put("frequency", rs.getString("frequency"))
                .put("targetCount", rs.getInt("target_count"))
                .put("color", rs.getString("color"))
                .put("icon", rs.getString("icon"))
                .put("isActive", rs.getInt("is_active") == 1)
                .put("completedToday", rs.getInt("completed_today") > 0)
                .put("totalCompletions", rs.getInt("total_completions"))
                .put("createdAt", rs.getString("created_at"));
    }

    private boolean verifyOwnership(long habitId, long userId) throws SQLException {
        try (ResultSet rs = Database.query(
                "SELECT id FROM habits WHERE id = ? AND user_id = ?", habitId, userId)) {
            return rs.next();
        }
    }

    private Map<String, String> parseQuery(String query) {
        Map<String, String> params = new HashMap<>();
        if (query != null && !query.isEmpty()) {
            for (String param : query.split("&")) {
                String[] kv = param.split("=", 2);
                if (kv.length == 2) {
                    params.put(kv[0], kv[1]);
                }
            }
        }
        return params;
    }

    private void handleCors(HttpExchange exchange) throws IOException {
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");
        exchange.sendResponseHeaders(204, -1);
    }
}
