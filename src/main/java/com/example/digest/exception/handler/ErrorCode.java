package com.example.digest.exception.handler;

public enum ErrorCode {
    DUPLICATE_EMAIL(1001, "Email is already registered."),
    USER_NOT_FOUND(1002, "User not found."),
    VALIDATION_ERROR(1003, "Validation failed."),
    INTERNAL_SERVER_ERROR(1004, "Internal server error.");

    private final int code;
    private final String message;

    ErrorCode(int code, String message) {
        this.code = code;
        this.message = message;
    }

    public int getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }
}
