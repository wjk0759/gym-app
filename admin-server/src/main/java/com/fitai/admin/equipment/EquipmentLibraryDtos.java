package com.fitai.admin.equipment;

public final class EquipmentLibraryDtos {

    private EquipmentLibraryDtos() {
    }

    public record Item(
            String id,
            String userId,
            String phone,
            String username,
            String clientId,
            String name,
            String slug,
            String muscle,
            String equipment,
            String notes,
            String source,
            String createdAt
    ) {
    }
}
