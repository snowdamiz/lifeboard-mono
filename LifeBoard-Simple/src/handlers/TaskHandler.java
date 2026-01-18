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
 * Task Handler
 * 
 * Manages calendar tasks with support for:
 * - CRUD operations on tasks
 * - Task steps (checklists)
 * - Task tags
 * - Filtering by date range
 * 
 * Endpoints:
 * GET /api/tasks - List all tasks (with optional filters)
 * POST /api/tasks - Create a task
 * GET /api/tasks/{id} - Get a specific task
 * PUT /api/tasks/{id} - Update a task
 * DELETE /api/tasks/{id} - Delete a task
 * POST /api/tasks/{id}/steps - Add a step
 * PUT /api/tasks/{id}/steps/{stepId} - Update a step
 * DELETE /api/tasks/{id}/steps/{stepId} - Delete a step
 */
public class TaskHandler implements HttpHandler {

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();
        String query = exchange.getRequestURI().getQuery();

        // Handle CORS preflight
        if (method.equals("OPTIONS")) {
            handleCors(exchange);
            return;
        }

        try {
            // Authenticate
            long userId = SessionUtil.getUserIdFromRequest(exchange);
            if (userId < 0) {
                Main.sendJson(exchange, 401, "{\"error\":\"Not authenticated\"}");
                return;
            }

            // Parse path: /api/tasks, /api/tasks/123, /api/tasks/123/steps, etc.
            String[] parts = path.split("/");

            if (parts.length == 3) {
                // /api/tasks
                if (method.equals("GET")) {
                    handleList(exchange, userId, query);
                } else if (method.equals("POST")) {
                    handleCreate(exchange, userId);
                } else {
                    Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                }
            } else if (parts.length == 4) {
                // /api/tasks/{id}
                long taskId = Long.parseLong(parts[3]);
                if (method.equals("GET")) {
                    handleGet(exchange, userId, taskId);
                } else if (method.equals("PUT")) {
                    handleUpdate(exchange, userId, taskId);
                } else if (method.equals("DELETE")) {
                    handleDelete(exchange, userId, taskId);
                } else {
                    Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                }
            } else if (parts.length >= 5 && parts[4].equals("steps")) {
                // /api/tasks/{id}/steps or /api/tasks/{id}/steps/{stepId}
                long taskId = Long.parseLong(parts[3]);
                if (parts.length == 5) {
                    if (method.equals("POST")) {
                        handleCreateStep(exchange, userId, taskId);
                    } else {
                        Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    }
                } else if (parts.length == 6) {
                    long stepId = Long.parseLong(parts[5]);
                    if (method.equals("PUT")) {
                        handleUpdateStep(exchange, userId, taskId, stepId);
                    } else if (method.equals("DELETE")) {
                        handleDeleteStep(exchange, userId, taskId, stepId);
                    } else {
                        Main.sendJson(exchange, 405, "{\"error\":\"Method not allowed\"}");
                    }
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

    /**
     * GET /api/tasks
     * Optional query params: date, startDate, endDate, status
     */
    private void handleList(HttpExchange exchange, long userId, String query)
            throws IOException, SQLException {

        // Parse query parameters
        Map<String, String> params = parseQuery(query);

        StringBuilder sql = new StringBuilder(
                "SELECT t.*, GROUP_CONCAT(tt.tag_id) as tag_ids " +
                        "FROM tasks t " +
                        "LEFT JOIN task_tags tt ON t.id = tt.task_id " +
                        "WHERE t.user_id = ? ");

        List<Object> sqlParams = new ArrayList<>();
        sqlParams.add(userId);

        // Filter by date range
        if (params.containsKey("startDate") && params.containsKey("endDate")) {
            sql.append("AND t.due_date BETWEEN ? AND ? ");
            sqlParams.add(params.get("startDate"));
            sqlParams.add(params.get("endDate"));
        } else if (params.containsKey("date")) {
            sql.append("AND t.due_date = ? ");
            sqlParams.add(params.get("date"));
        }

        // Filter by status
        if (params.containsKey("status")) {
            sql.append("AND t.status = ? ");
            sqlParams.add(params.get("status"));
        }

        sql.append("GROUP BY t.id ORDER BY t.due_date, t.due_time, t.sort_order");

        JsonArray tasks = JsonUtil.array();

        try (ResultSet rs = Database.query(sql.toString(), sqlParams.toArray())) {
            while (rs.next()) {
                tasks.add(taskToJson(rs, userId));
            }
        }

        Main.sendJson(exchange, 200, tasks.toString());
    }

    /**
     * POST /api/tasks
     */
    private void handleCreate(HttpExchange exchange, long userId)
            throws IOException, SQLException {

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String title = (String) data.get("title");
        if (title == null || title.trim().isEmpty()) {
            Main.sendJson(exchange, 400, "{\"error\":\"Title is required\"}");
            return;
        }

        long taskId = Database.insert(
                "INSERT INTO tasks (user_id, title, description, status, priority, due_date, due_time, duration_minutes) "
                        +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                userId,
                title,
                data.get("description"),
                data.getOrDefault("status", "pending"),
                data.getOrDefault("priority", 2),
                data.get("dueDate"),
                data.get("dueTime"),
                data.get("durationMinutes"));

        // Add tags if provided
        if (data.containsKey("tagIds") && data.get("tagIds") instanceof List) {
            List<?> tagIds = (List<?>) data.get("tagIds");
            for (Object tagId : tagIds) {
                Database.insert(
                        "INSERT INTO task_tags (task_id, tag_id) VALUES (?, ?)",
                        taskId, ((Number) tagId).longValue());
            }
        }

        // Add steps if provided
        if (data.containsKey("steps") && data.get("steps") instanceof List) {
            List<?> steps = (List<?>) data.get("steps");
            int order = 0;
            for (Object step : steps) {
                if (step instanceof Map) {
                    Map<?, ?> stepData = (Map<?, ?>) step;
                    Database.insert(
                            "INSERT INTO task_steps (task_id, title, sort_order) VALUES (?, ?, ?)",
                            taskId, stepData.get("title"), order++);
                }
            }
        }

        // Return created task
        try (ResultSet rs = Database.query(
                "SELECT * FROM tasks WHERE id = ?", taskId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 201, taskToJson(rs, userId).toString());
            }
        }
    }

    /**
     * GET /api/tasks/{id}
     */
    private void handleGet(HttpExchange exchange, long userId, long taskId)
            throws IOException, SQLException {

        try (ResultSet rs = Database.query(
                "SELECT * FROM tasks WHERE id = ? AND user_id = ?",
                taskId, userId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 200, taskToJson(rs, userId).toString());
            } else {
                Main.sendJson(exchange, 404, "{\"error\":\"Task not found\"}");
            }
        }
    }

    /**
     * PUT /api/tasks/{id}
     */
    private void handleUpdate(HttpExchange exchange, long userId, long taskId)
            throws IOException, SQLException {

        // Verify ownership
        if (!verifyOwnership(taskId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Task not found\"}");
            return;
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        // Build update query dynamically
        StringBuilder sql = new StringBuilder("UPDATE tasks SET updated_at = CURRENT_TIMESTAMP");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("title")) {
            sql.append(", title = ?");
            params.add(data.get("title"));
        }
        if (data.containsKey("description")) {
            sql.append(", description = ?");
            params.add(data.get("description"));
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
        if (data.containsKey("dueDate")) {
            sql.append(", due_date = ?");
            params.add(data.get("dueDate"));
        }
        if (data.containsKey("dueTime")) {
            sql.append(", due_time = ?");
            params.add(data.get("dueTime"));
        }
        if (data.containsKey("durationMinutes")) {
            sql.append(", duration_minutes = ?");
            params.add(data.get("durationMinutes"));
        }

        sql.append(" WHERE id = ?");
        params.add(taskId);

        Database.update(sql.toString(), params.toArray());

        // Update tags if provided
        if (data.containsKey("tagIds")) {
            Database.update("DELETE FROM task_tags WHERE task_id = ?", taskId);
            if (data.get("tagIds") instanceof List) {
                List<?> tagIds = (List<?>) data.get("tagIds");
                for (Object tagId : tagIds) {
                    Database.insert(
                            "INSERT INTO task_tags (task_id, tag_id) VALUES (?, ?)",
                            taskId, ((Number) tagId).longValue());
                }
            }
        }

        // Return updated task
        try (ResultSet rs = Database.query(
                "SELECT * FROM tasks WHERE id = ?", taskId)) {
            if (rs.next()) {
                Main.sendJson(exchange, 200, taskToJson(rs, userId).toString());
            }
        }
    }

    /**
     * DELETE /api/tasks/{id}
     */
    private void handleDelete(HttpExchange exchange, long userId, long taskId)
            throws IOException, SQLException {

        int deleted = Database.update(
                "DELETE FROM tasks WHERE id = ? AND user_id = ?",
                taskId, userId);

        if (deleted > 0) {
            Main.sendJson(exchange, 200, "{\"success\":true}");
        } else {
            Main.sendJson(exchange, 404, "{\"error\":\"Task not found\"}");
        }
    }

    /**
     * POST /api/tasks/{id}/steps
     */
    private void handleCreateStep(HttpExchange exchange, long userId, long taskId)
            throws IOException, SQLException {

        if (!verifyOwnership(taskId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Task not found\"}");
            return;
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        String title = (String) data.get("title");
        if (title == null || title.trim().isEmpty()) {
            Main.sendJson(exchange, 400, "{\"error\":\"Title is required\"}");
            return;
        }

        // Get max sort order
        int maxOrder = 0;
        try (ResultSet rs = Database.query(
                "SELECT MAX(sort_order) as max_order FROM task_steps WHERE task_id = ?",
                taskId)) {
            if (rs.next()) {
                maxOrder = rs.getInt("max_order") + 1;
            }
        }

        long stepId = Database.insert(
                "INSERT INTO task_steps (task_id, title, sort_order) VALUES (?, ?, ?)",
                taskId, title, maxOrder);

        String response = JsonUtil.object()
                .put("id", stepId)
                .put("taskId", taskId)
                .put("title", title)
                .put("completed", false)
                .put("sortOrder", maxOrder)
                .toString();

        Main.sendJson(exchange, 201, response);
    }

    /**
     * PUT /api/tasks/{id}/steps/{stepId}
     */
    private void handleUpdateStep(HttpExchange exchange, long userId, long taskId, long stepId)
            throws IOException, SQLException {

        if (!verifyOwnership(taskId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Task not found\"}");
            return;
        }

        String body = Main.readBody(exchange);
        Map<String, Object> data = JsonUtil.parse(body);

        StringBuilder sql = new StringBuilder("UPDATE task_steps SET task_id = task_id");
        List<Object> params = new ArrayList<>();

        if (data.containsKey("title")) {
            sql.append(", title = ?");
            params.add(data.get("title"));
        }
        if (data.containsKey("completed")) {
            sql.append(", completed = ?");
            params.add(Boolean.TRUE.equals(data.get("completed")) ? 1 : 0);
        }
        if (data.containsKey("sortOrder")) {
            sql.append(", sort_order = ?");
            params.add(data.get("sortOrder"));
        }

        sql.append(" WHERE id = ? AND task_id = ?");
        params.add(stepId);
        params.add(taskId);

        Database.update(sql.toString(), params.toArray());

        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    /**
     * DELETE /api/tasks/{id}/steps/{stepId}
     */
    private void handleDeleteStep(HttpExchange exchange, long userId, long taskId, long stepId)
            throws IOException, SQLException {

        if (!verifyOwnership(taskId, userId)) {
            Main.sendJson(exchange, 404, "{\"error\":\"Task not found\"}");
            return;
        }

        Database.update(
                "DELETE FROM task_steps WHERE id = ? AND task_id = ?",
                stepId, taskId);

        Main.sendJson(exchange, 200, "{\"success\":true}");
    }

    // ========================================================================
    // Helper Methods
    // ========================================================================

    private JsonObject taskToJson(ResultSet rs, long userId) throws SQLException {
        long taskId = rs.getLong("id");

        JsonObject task = JsonUtil.object()
                .put("id", taskId)
                .put("title", rs.getString("title"))
                .put("description", rs.getString("description"))
                .put("status", rs.getString("status"))
                .put("priority", rs.getInt("priority"))
                .put("dueDate", rs.getString("due_date"))
                .put("dueTime", rs.getString("due_time"))
                .put("durationMinutes", rs.getObject("duration_minutes"))
                .put("completedAt", rs.getString("completed_at"))
                .put("sortOrder", rs.getInt("sort_order"))
                .put("createdAt", rs.getString("created_at"))
                .put("updatedAt", rs.getString("updated_at"));

        // Load steps
        JsonArray steps = JsonUtil.array();
        try (ResultSet stepsRs = Database.query(
                "SELECT * FROM task_steps WHERE task_id = ? ORDER BY sort_order",
                taskId)) {
            while (stepsRs.next()) {
                steps.add(JsonUtil.object()
                        .put("id", stepsRs.getLong("id"))
                        .put("title", stepsRs.getString("title"))
                        .put("completed", stepsRs.getInt("completed") == 1)
                        .put("sortOrder", stepsRs.getInt("sort_order")));
            }
        }
        task.put("steps", steps);

        // Load tags
        JsonArray tags = JsonUtil.array();
        try (ResultSet tagsRs = Database.query(
                "SELECT t.* FROM tags t " +
                        "JOIN task_tags tt ON t.id = tt.tag_id " +
                        "WHERE tt.task_id = ?",
                taskId)) {
            while (tagsRs.next()) {
                tags.add(JsonUtil.object()
                        .put("id", tagsRs.getLong("id"))
                        .put("name", tagsRs.getString("name"))
                        .put("color", tagsRs.getString("color")));
            }
        }
        task.put("tags", tags);

        return task;
    }

    private boolean verifyOwnership(long taskId, long userId) throws SQLException {
        try (ResultSet rs = Database.query(
                "SELECT id FROM tasks WHERE id = ? AND user_id = ?",
                taskId, userId)) {
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
