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
 * Goals Handler
 * 
 * Manages goals, milestones, and goal categories.
 * 
 * Endpoints:
 * GET /api/goal-categories - List categories
 * POST /api/goal-categories - Create category
 * PUT /api/goal-categories/{id} - Update category
 * DELETE /api/goal-categories/{id} - Delete category
 * GET /api/goals - List goals
 * POST /api/goals - Create goal
 * GET /api/goals/{id} - Get goal with milestones
 * PUT /api/goals/{id} - Update goal
 * DELETE /api/goals/{id} - Delete goal
 * POST /api/goals/{id}/milestones - Add milestone
 * PUT /api/goals/{id}/milestones/{id} - Update milestone
 * DELETE /api/goals/{id}/milestones/{id} - Delete milestone
 */
public class GoalsHandler implements HttpHandler {

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

            if (path.startsWith("/api/goal-categories")) {
                handleCategories(exchange, method, parts, userId);
            } else if (path.startsWith("/api/goals")) {
                handleGoals(exchange, method, parts, userId);
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

    // ========================================================================
    // CATEGORIES
    // ========================================================================

    private void handleCategories(HttpExchange exchange, String method, String[] parts, long userId)
            throws IOException, SQLException {

        if (parts.length == 3) {
            if (method.equals("GET"))
                listCategories(exchange, userId);
            else if (method.equals("POST"))
                createCategory(exchange, userId);
            else
                Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
        } else if (parts.length == 4) {
            long categoryId = Long.parseLong(parts[3]);
            if (method.equals("PUT"))
                updateCategory(exchange, userId, categoryId);
            else if (method.equals("DELETE"))
                deleteCategory(exchange, userId, categoryId);
            else
                Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
        }
    }

    private void listCategories(HttpExchange exchange, long userId) throws IOException, SQLException {
        JsonArray categories = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT * FROM goal_categories WHERE user_id = ? ORDER BY sort_order, name",
                userId)) {
            while (rs.next()) {
                categories.add(JsonUtil.object()
                        .put("id", rs.getLong("id"))
                        .put("name", rs.getString("name"))
                        .put("color", rs.getString("color"))
                        .put("icon", rs.getString("icon")));
            }
        }

        Main.sendJson(exchange, 200, categories.toString());
    }

    private void createCategory(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String name = (String) data.get("name");
        if (name == null) {
            Main.sendJson(exchange, 400, "{\"error\":\"Name is required\"}");
            return;
        }

        long id = Database.insert(
                "INSERT INTO goal_categories (user_id, name, color, icon) VALUES (?, ?, ?, ?)",
                userId, name,
                data.getOrDefault("color", "#F59E0B"),
                data.getOrDefault("icon", "🎯"));

        String response = JsonUtil.object()
                .put("id", id)
                .put("name", name)
                .put("color", data.getOrDefault("color", "#F59E0B"))
                .put("icon", data.getOrDefault("icon", "🎯"))
                .toString();

        Main.sendJson(exchange, 201, response);
    }

    private void updateCategory(HttpExchange exchange, long userId, long categoryId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE goal_categories SET user_id = user_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("name")) {
            sql.append(", name = ?");
            params.add(data.get("name"));
        }
        if (data.containsKey("color")) {
            sql.append(", color = ?");
            params.add(data.get("color"));
        }
        if (data.containsKey("icon")) {
            sql.append(", icon = ?");
            params.add(data.get("icon"));
        }

        sql.append(" WHERE id = ? AND user_id = ?");
        params.add(categoryId);
        params.add(userId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteCategory(HttpExchange exchange, long userId, long categoryId) throws IOException, SQLException {
        Database.update("DELETE FROM goal_categories WHERE id = ? AND user_id = ?", categoryId, userId);
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    // ========================================================================
    // GOALS
    // ========================================================================

    private void handleGoals(HttpExchange exchange, String method, String[] parts, long userId)
            throws IOException, SQLException {

        if (parts.length == 3) {
            if (method.equals("GET"))
                listGoals(exchange, userId);
            else if (method.equals("POST"))
                createGoal(exchange, userId);
            else
                Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
        } else if (parts.length == 4) {
            long goalId = Long.parseLong(parts[3]);
            if (method.equals("GET"))
                getGoal(exchange, userId, goalId);
            else if (method.equals("PUT"))
                updateGoal(exchange, userId, goalId);
            else if (method.equals("DELETE"))
                deleteGoal(exchange, userId, goalId);
            else
                Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
        } else if (parts.length >= 5 && parts[4].equals("milestones")) {
            long goalId = Long.parseLong(parts[3]);
            if (parts.length == 5 && method.equals("POST")) {
                createMilestone(exchange, userId, goalId);
            } else if (parts.length == 6) {
                long milestoneId = Long.parseLong(parts[5]);
                if (method.equals("PUT"))
                    updateMilestone(exchange, userId, goalId, milestoneId);
                else if (method.equals("DELETE"))
                    deleteMilestone(exchange, userId, goalId, milestoneId);
                else
                    Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
            }
        }
    }

    private void listGoals(HttpExchange exchange, long userId) throws IOException, SQLException {
        JsonArray goals = JsonUtil.array();

        try (ResultSet rs = Database.query(
                "SELECT g.*, c.name as category_name, c.color as category_color " +
                        "FROM goals g " +
                        "LEFT JOIN goal_categories c ON g.category_id = c.id " +
                        "WHERE g.user_id = ? ORDER BY g.status, g.priority DESC, g.target_date",
                userId)) {
            while (rs.next()) {
                goals.add(goalToJson(rs));
            }
        }

        Main.sendJson(exchange, 200, goals.toString());
    }

    private void createGoal(HttpExchange exchange, long userId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String title = (String) data.get("title");
        if (title == null) {
            Main.sendJson(exchange, 400, "{\"error\":\"Title is required\"}");
            return;
        }

        long goalId = Database.insert(
                "INSERT INTO goals (user_id, category_id, title, description, priority, target_date) " +
                        "VALUES (?, ?, ?, ?, ?, ?)",
                userId,
                data.get("categoryId") != null ? ((Number) data.get("categoryId")).longValue() : null,
                title,
                data.get("description"),
                data.getOrDefault("priority", 2),
                data.get("targetDate"));

        try (ResultSet rs = Database.query(
                "SELECT g.*, c.name as category_name, c.color as category_color " +
                        "FROM goals g LEFT JOIN goal_categories c ON g.category_id = c.id WHERE g.id = ?",
                goalId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, goalToJson(rs).toString());
            }
        }
    }

    private void getGoal(HttpExchange exchange, long userId, long goalId) throws IOException, SQLException {
        try (ResultSet rs = Database.query(
                "SELECT g.*, c.name as category_name, c.color as category_color " +
                        "FROM goals g LEFT JOIN goal_categories c ON g.category_id = c.id " +
                        "WHERE g.id = ? AND g.user_id = ?",
                goalId, userId)) {
            if (rs.next()) {
                JsonObject goal = goalToJson(rs);

                // Load milestones
                JsonArray milestones = JsonUtil.array();
                try (ResultSet mRs = Database.query(
                        "SELECT * FROM goal_milestones WHERE goal_id = ? ORDER BY sort_order, target_date",
                        goalId)) {
                    while (mRs.next()) {
                        milestones.add(JsonUtil.object()
                                .put("id", mRs.getLong("id"))
                                .put("title", mRs.getString("title"))
                                .put("description", mRs.getString("description"))
                                .put("completed", mRs.getInt("completed") == 1)
                                .put("targetDate", mRs.getString("target_date"))
                                .put("completedAt", mRs.getString("completed_at")));
                    }
                }
                goal.put("milestones", milestones);

                Main.sendJson(exchange, 200, goal.toString());
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Goal not found\"}");
            }
        }
    }

    private void updateGoal(HttpExchange exchange, long userId, long goalId) throws IOException, SQLException {
        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE goals SET updated_at = CURRENT_TIMESTAMP");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("title")) {
            sql.append(", title = ?");
            params.add(data.get("title"));
        }
        if (data.containsKey("description")) {
            sql.append(", description = ?");
            params.add(data.get("description"));
        }
        if (data.containsKey("categoryId")) {
            sql.append(", category_id = ?");
            params.add(data.get("categoryId"));
        }
        if (data.containsKey("status")) {
            sql.append(", status = ?");
            params.add(data.get("status"));
            if ("completed".equals(data.get("status"))) {
                sql.append(", completed_at = CURRENT_TIMESTAMP");
            }
        }
        if (data.containsKey("priority")) {
            sql.append(", priority = ?");
            params.add(data.get("priority"));
        }
        if (data.containsKey("targetDate")) {
            sql.append(", target_date = ?");
            params.add(data.get("targetDate"));
        }
        if (data.containsKey("progress")) {
            sql.append(", progress = ?");
            params.add(data.get("progress"));
        }

        sql.append(" WHERE id = ? AND user_id = ?");
        params.add(goalId);
        params.add(userId);

        Database.update(sql.toString(), params.toArray());
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteGoal(HttpExchange exchange, long userId, long goalId) throws IOException, SQLException {
        Database.update("DELETE FROM goals WHERE id = ? AND user_id = ?", goalId, userId);
        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    // ========================================================================
    // MILESTONES
    // ========================================================================

    private void createMilestone(HttpExchange exchange, long userId, long goalId) throws IOException, SQLException {
        if (!verifyGoalOwnership(goalId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Goal not found\"}");
            return;
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String title = (String) data.get("title");
        if (title == null) {
            Main.sendJson(exchange, 400, "{\"error\":\"Title is required\"}");
            return;
        }

        long id = Database.insert(
                "INSERT INTO goal_milestones (goal_id, title, description, target_date) VALUES (?, ?, ?, ?)",
                goalId, title, data.get("description"), data.get("targetDate"));

        String response = JsonUtil.object()
                .put("id", id)
                .put("goalId", goalId)
                .put("title", title)
                .put("completed", false)
                .toString();

        Main.sendJson(exchange, 201, response);
    }

    private void updateMilestone(HttpExchange exchange, long userId, long goalId, long milestoneId)
            throws IOException, SQLException {
        if (!verifyGoalOwnership(goalId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Goal not found\"}");
            return;
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE goal_milestones SET goal_id = goal_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("title")) {
            sql.append(", title = ?");
            params.add(data.get("title"));
        }
        if (data.containsKey("description")) {
            sql.append(", description = ?");
            params.add(data.get("description"));
        }
        if (data.containsKey("targetDate")) {
            sql.append(", target_date = ?");
            params.add(data.get("targetDate"));
        }
        if (data.containsKey("completed")) {
            sql.append(", completed = ?");
            params.add(Boolean.TRUE.equals(data.get("completed")) ? 1 : 0);
            if (Boolean.TRUE.equals(data.get("completed"))) {
                sql.append(", completed_at = CURRENT_TIMESTAMP");
            } else {
                sql.append(", completed_at = NULL");
            }
        }

        sql.append(" WHERE id = ? AND goal_id = ?");
        params.add(milestoneId);
        params.add(goalId);

        Database.update(sql.toString(), params.toArray());

        // Update goal progress
        updateGoalProgress(goalId);

        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void deleteMilestone(HttpExchange exchange, long userId, long goalId, long milestoneId)
            throws IOException, SQLException {
        if (!verifyGoalOwnership(goalId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Goal not found\"}");
            return;
        }

        Database.update("DELETE FROM goal_milestones WHERE id = ? AND goal_id = ?", milestoneId, goalId);
        updateGoalProgress(goalId);

        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    private void updateGoalProgress(long goalId) throws SQLException {
        // Calculate progress based on completed milestones
        try (ResultSet rs = Database.query(
                "SELECT COUNT(*) as total, SUM(completed) as done FROM goal_milestones WHERE goal_id = ?",
                goalId)) {
            if (rs.next()) {
                int total = rs.getInt("total");
                int done = rs.getInt("done");
                int progress = total > 0 ? (done * 100 / total) : 0;
                Database.update("UPDATE goals SET progress = ? WHERE id = ?", progress, goalId);
            }
        }
    }

    private JsonObject goalToJson(ResultSet rs) throws SQLException {
        return JsonUtil.object()
                .put("id", rs.getLong("id"))
                .put("title", rs.getString("title"))
                .put("description", rs.getString("description"))
                .put("categoryId", rs.getObject("category_id"))
                .put("categoryName", rs.getString("category_name"))
                .put("categoryColor", rs.getString("category_color"))
                .put("status", rs.getString("status"))
                .put("priority", rs.getInt("priority"))
                .put("targetDate", rs.getString("target_date"))
                .put("progress", rs.getInt("progress"))
                .put("createdAt", rs.getString("created_at"))
                .put("updatedAt", rs.getString("updated_at"))
                .put("completedAt", rs.getString("completed_at"));
    }

    private boolean verifyGoalOwnership(long goalId, long userId) throws SQLException {
        try (ResultSet rs = Database.query(
                "SELECT id FROM goals WHERE id = ? AND user_id = ?", goalId, userId)) {
            return rs.next();
        }
    }

    private void handleCors(HttpExchange exchange) throws IOException {
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        exchange.getResponseHeaders().add("Access-Control-Allow-Headers", "Content-Type, Authorization");
        exchange.sendResponseHeaders(204, -1);
    }
}
