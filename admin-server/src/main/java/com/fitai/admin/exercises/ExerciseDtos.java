package com.fitai.admin.exercises;

import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public final class ExerciseDtos {

    private ExerciseDtos() {
    }

    public record ExerciseItem(
            String slug,
            String nameZh,
            String nameEn,
            String muscleGroup,
            String equipment,
            boolean compound,
            int difficulty,
            String instructions,
            String videoUrl,
            String thumbnailUrl,
            Object contraindications,
            String source,
            String license,
            String createdAt
    ) {
    }

    public record PatchExerciseRequest(
            @Size(max = 80) String nameZh,
            @Size(max = 120) String nameEn,
            @Size(max = 20) String muscleGroup,
            @Size(max = 20) String equipment,
            Boolean compound,
            @Min(1) @Max(5) Integer difficulty,
            @Size(max = 5000) String instructions,
            @Size(max = 2000) String videoUrl,
            @Size(max = 2000) String thumbnailUrl,
            List<String> contraindications,
            @Size(max = 40) String source,
            @Size(max = 120) String license
    ) {
        public boolean isEmpty() {
            return nameZh == null && nameEn == null && muscleGroup == null && equipment == null
                    && compound == null && difficulty == null && instructions == null
                    && videoUrl == null && thumbnailUrl == null && contraindications == null
                    && source == null && license == null;
        }
    }
}
