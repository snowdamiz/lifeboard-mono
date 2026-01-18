package lifeboard.util;

import java.util.*;
import java.util.regex.*;

/**
 * Simple JSON Utility Class
 * 
 * A minimal JSON parser/builder that works without external libraries.
 * For human readability - no complex parsing libraries needed!
 * 
 * Usage:
 * // Building JSON
 * String json = JsonUtil.object()
 * .put("name", "Test")
 * .put("count", 42)
 * .put("active", true)
 * .toString();
 * 
 * // Parsing JSON
 * Map<String, Object> data = JsonUtil.parse(jsonString);
 */
public class JsonUtil {

    /**
     * Create a new JSON object builder
     */
    public static JsonObject object() {
        return new JsonObject();
    }

    /**
     * Create a new JSON array builder
     */
    public static JsonArray array() {
        return new JsonArray();
    }

    /**
     * Parse a JSON string into a Map
     */
    public static Map<String, Object> parse(String json) {
        if (json == null || json.trim().isEmpty()) {
            return new HashMap<>();
        }
        return new JsonParser(json.trim()).parseObject();
    }

    /**
     * Parse a JSON array string into a List
     */
    public static List<Object> parseArray(String json) {
        if (json == null || json.trim().isEmpty()) {
            return new ArrayList<>();
        }
        return new JsonParser(json.trim()).parseArray();
    }

    /**
     * Escape a string for JSON
     */
    public static String escape(String s) {
        if (s == null)
            return "null";
        StringBuilder sb = new StringBuilder();
        for (char c : s.toCharArray()) {
            switch (c) {
                case '"':
                    sb.append("\\\"");
                    break;
                case '\\':
                    sb.append("\\\\");
                    break;
                case '\b':
                    sb.append("\\b");
                    break;
                case '\f':
                    sb.append("\\f");
                    break;
                case '\n':
                    sb.append("\\n");
                    break;
                case '\r':
                    sb.append("\\r");
                    break;
                case '\t':
                    sb.append("\\t");
                    break;
                default:
                    if (c < ' ') {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
            }
        }
        return sb.toString();
    }

    // ========================================================================
    // JSON Object Builder
    // ========================================================================

    public static class JsonObject {
        private final Map<String, Object> map = new LinkedHashMap<>();

        public JsonObject put(String key, Object value) {
            map.put(key, value);
            return this;
        }

        public JsonObject put(String key, JsonObject obj) {
            map.put(key, obj);
            return this;
        }

        public JsonObject put(String key, JsonArray arr) {
            map.put(key, arr);
            return this;
        }

        public Map<String, Object> toMap() {
            return new HashMap<>(map);
        }

        @Override
        public String toString() {
            StringBuilder sb = new StringBuilder("{");
            boolean first = true;
            for (Map.Entry<String, Object> entry : map.entrySet()) {
                if (!first)
                    sb.append(",");
                first = false;
                sb.append("\"").append(escape(entry.getKey())).append("\":");
                sb.append(valueToString(entry.getValue()));
            }
            sb.append("}");
            return sb.toString();
        }
    }

    // ========================================================================
    // JSON Array Builder
    // ========================================================================

    public static class JsonArray {
        private final List<Object> list = new ArrayList<>();

        public JsonArray add(Object value) {
            list.add(value);
            return this;
        }

        public JsonArray add(JsonObject obj) {
            list.add(obj);
            return this;
        }

        public JsonArray add(JsonArray arr) {
            list.add(arr);
            return this;
        }

        public List<Object> toList() {
            return new ArrayList<>(list);
        }

        @Override
        public String toString() {
            StringBuilder sb = new StringBuilder("[");
            boolean first = true;
            for (Object value : list) {
                if (!first)
                    sb.append(",");
                first = false;
                sb.append(valueToString(value));
            }
            sb.append("]");
            return sb.toString();
        }
    }

    // ========================================================================
    // Helper Methods
    // ========================================================================

    private static String valueToString(Object value) {
        if (value == null) {
            return "null";
        } else if (value instanceof String) {
            return "\"" + escape((String) value) + "\"";
        } else if (value instanceof Number || value instanceof Boolean) {
            return value.toString();
        } else if (value instanceof JsonObject || value instanceof JsonArray) {
            return value.toString();
        } else if (value instanceof Map) {
            JsonObject obj = object();
            for (Map.Entry<?, ?> e : ((Map<?, ?>) value).entrySet()) {
                obj.put(e.getKey().toString(), e.getValue());
            }
            return obj.toString();
        } else if (value instanceof List) {
            JsonArray arr = array();
            for (Object item : (List<?>) value) {
                arr.add(item);
            }
            return arr.toString();
        } else {
            return "\"" + escape(value.toString()) + "\"";
        }
    }

    // ========================================================================
    // Simple JSON Parser
    // ========================================================================

    private static class JsonParser {
        private final String json;
        private int pos = 0;

        JsonParser(String json) {
            this.json = json;
        }

        Map<String, Object> parseObject() {
            Map<String, Object> map = new LinkedHashMap<>();
            expect('{');
            skipWhitespace();
            if (peek() != '}') {
                do {
                    skipWhitespace();
                    String key = parseString();
                    skipWhitespace();
                    expect(':');
                    skipWhitespace();
                    Object value = parseValue();
                    map.put(key, value);
                    skipWhitespace();
                } while (consume(','));
            }
            expect('}');
            return map;
        }

        List<Object> parseArray() {
            List<Object> list = new ArrayList<>();
            expect('[');
            skipWhitespace();
            if (peek() != ']') {
                do {
                    skipWhitespace();
                    list.add(parseValue());
                    skipWhitespace();
                } while (consume(','));
            }
            expect(']');
            return list;
        }

        Object parseValue() {
            skipWhitespace();
            char c = peek();
            if (c == '"')
                return parseString();
            if (c == '{')
                return parseObject();
            if (c == '[')
                return parseArray();
            if (c == 't' || c == 'f')
                return parseBoolean();
            if (c == 'n')
                return parseNull();
            if (c == '-' || Character.isDigit(c))
                return parseNumber();
            throw new RuntimeException("Unexpected character: " + c + " at position " + pos);
        }

        String parseString() {
            expect('"');
            StringBuilder sb = new StringBuilder();
            while (pos < json.length()) {
                char c = json.charAt(pos++);
                if (c == '"')
                    return sb.toString();
                if (c == '\\') {
                    c = json.charAt(pos++);
                    switch (c) {
                        case '"':
                            sb.append('"');
                            break;
                        case '\\':
                            sb.append('\\');
                            break;
                        case '/':
                            sb.append('/');
                            break;
                        case 'b':
                            sb.append('\b');
                            break;
                        case 'f':
                            sb.append('\f');
                            break;
                        case 'n':
                            sb.append('\n');
                            break;
                        case 'r':
                            sb.append('\r');
                            break;
                        case 't':
                            sb.append('\t');
                            break;
                        case 'u':
                            String hex = json.substring(pos, pos + 4);
                            sb.append((char) Integer.parseInt(hex, 16));
                            pos += 4;
                            break;
                        default:
                            sb.append(c);
                    }
                } else {
                    sb.append(c);
                }
            }
            throw new RuntimeException("Unterminated string");
        }

        Number parseNumber() {
            int start = pos;
            if (peek() == '-')
                pos++;
            while (pos < json.length() && Character.isDigit(peek()))
                pos++;
            if (pos < json.length() && peek() == '.') {
                pos++;
                while (pos < json.length() && Character.isDigit(peek()))
                    pos++;
            }
            if (pos < json.length() && (peek() == 'e' || peek() == 'E')) {
                pos++;
                if (peek() == '+' || peek() == '-')
                    pos++;
                while (pos < json.length() && Character.isDigit(peek()))
                    pos++;
            }
            String numStr = json.substring(start, pos);
            if (numStr.contains(".") || numStr.contains("e") || numStr.contains("E")) {
                return Double.parseDouble(numStr);
            } else {
                long val = Long.parseLong(numStr);
                if (val >= Integer.MIN_VALUE && val <= Integer.MAX_VALUE) {
                    return (int) val;
                }
                return val;
            }
        }

        Boolean parseBoolean() {
            if (json.startsWith("true", pos)) {
                pos += 4;
                return true;
            } else if (json.startsWith("false", pos)) {
                pos += 5;
                return false;
            }
            throw new RuntimeException("Expected boolean at position " + pos);
        }

        Object parseNull() {
            if (json.startsWith("null", pos)) {
                pos += 4;
                return null;
            }
            throw new RuntimeException("Expected null at position " + pos);
        }

        char peek() {
            return pos < json.length() ? json.charAt(pos) : 0;
        }

        void expect(char c) {
            if (peek() != c) {
                throw new RuntimeException("Expected '" + c + "' at position " + pos + " but found '" + peek() + "'");
            }
            pos++;
        }

        boolean consume(char c) {
            if (peek() == c) {
                pos++;
                return true;
            }
            return false;
        }

        void skipWhitespace() {
            while (pos < json.length() && Character.isWhitespace(json.charAt(pos))) {
                pos++;
            }
        }
    }
}
