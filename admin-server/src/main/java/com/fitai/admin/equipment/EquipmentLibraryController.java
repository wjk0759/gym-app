package com.fitai.admin.equipment;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

@RestController
@RequestMapping("/api/admin/v1/equipment-library")
public class EquipmentLibraryController {

    private final EquipmentLibraryRepository repository;

    public EquipmentLibraryController(EquipmentLibraryRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('exercise:read')")
    public PageResponse<EquipmentLibraryDtos.Item> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String source,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return repository.list(q, source, page, size);
    }
}
