package lifeboard.util;

import com.sun.net.httpserver.HttpExchange;
import lifeboard.db.Database;

import java.sql.*;
import java.util.*;
import java.security.SecureRandom;

/**
 * Session Management Utility
 * 
 * Handles user authentication sessions using secure random tokens.
 * Sessions are stored in the database for persistence across restarts.
 */
public class SessionUtil {

    private static final SecureRandom random = new SecureRandom();
    private static final int TOKEN_LENGTH = 32;
    private static final long SESSION_DURATION_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

    /**
     * Create a new session for a user
     * Returns the session token
     */
    public static String createSession(long userId) throws SQLException {
        String token = generateToken();

        Timestamp expiresAt = new Timestamp(System.currentTimeMillis() + SESSION_DURATION_MS);

        Database.insert(
                "INSERT INTO sessions (user_id, token, expires_at) VALUES (?, ?, ?)",
                userId, token, expiresAt);

        return token;
    }

    /**
     * Validate a session token and return the user ID
     * Returns -1 if invalid or expired
     */
    public static long validateSession(String token) throws SQLException {
        if (token == null || token.isEmpty()) {
            return -1;
        }

        try (ResultSet rs = Database.query(
                "SELECT user_id, expires_at FROM sessions WHERE token = ?", token)) {
            if (rs.next()) {
                Timestamp expiresAt = rs.getTimestamp("expires_at");
                if (expiresAt.after(new Timestamp(System.currentTimeMillis()))) {
                    return rs.getLong("user_id");
                } else {
                    // Session expired, delete it
                    Database.update("DELETE FROM sessions WHERE token = ?", token);
                }
            }
        }
        return -1;
    }

    /**
     * Get user ID from HTTP request Authorization header
     */
    public static long getUserIdFromRequest(HttpExchange exchange) throws SQLException {
        String authHeader = exchange.getRequestHeaders().getFirst("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            return validateSession(token);
        }

        // Also check for cookie-based auth
        String cookies = exchange.getRequestHeaders().getFirst("Cookie");
        if (cookies != null) {
            for (String cookie : cookies.split(";")) {
                String[] parts = cookie.trim().split("=", 2);
                if (parts.length == 2 && parts[0].equals("session")) {
                    return validateSession(parts[1]);
                }
            }
        }

        return -1;
    }

    /**
     * Delete a session (logout)
     */
    public static void deleteSession(String token) throws SQLException {
        Database.update("DELETE FROM sessions WHERE token = ?", token);
    }

    /**
     * Delete all sessions for a user
     */
    public static void deleteAllUserSessions(long userId) throws SQLException {
        Database.update("DELETE FROM sessions WHERE user_id = ?", userId);
    }

    /**
     * Clean up expired sessions (call periodically)
     */
    public static void cleanupExpiredSessions() throws SQLException {
        Database.update(
                "DELETE FROM sessions WHERE expires_at < ?",
                new Timestamp(System.currentTimeMillis()));
    }

    /**
     * Generate a secure random token
     */
    private static String generateToken() {
        byte[] bytes = new byte[TOKEN_LENGTH];
        random.nextBytes(bytes);
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    /**
     * Hash a password using a simple approach
     * (In production, use bcrypt or similar)
     */
    public static String hashPassword(String password) {
        // Simple hash for demo - in production use bcrypt!
        try {
            java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(password.getBytes("UTF-8"));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Failed to hash password", e);
        }
    }

    /**
     * Verify a password against its hash
     */
    public static boolean verifyPassword(String password, String hash) {
        return hashPassword(password).equals(hash);
    }
}
