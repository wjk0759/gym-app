package com.fitai.admin.common.persistence;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;

@Component
public class JsonCodec {

    private final ObjectMapper objectMapper;

    public JsonCodec(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /**
     * JDBC returns JSON columns as strings. Parse them for API responses while
     * remaining tolerant of legacy rows that contain plain text.
     */
    public Object parse(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof String text) {
            if (text.isBlank()) {
                return null;
            }
            char first = text.charAt(0);
            if (first != '{' && first != '[' && first != '"') {
                return text;
            }
            try {
                return objectMapper.readValue(text, Object.class);
            } catch (JsonProcessingException ignored) {
                return text;
            }
        }
        return value;
    }

    public String write(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof String text) {
            return text;
        }
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException ex) {
            throw new IllegalArgumentException("无法序列化 JSON 字段", ex);
        }
    }
}
