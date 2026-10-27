package com.fitai.admin.agent;

import java.util.List;

public final class AgentDtos {

    private AgentDtos() {
    }

    public record AgentRunItem(
            String id,
            String userId,
            String userLabel,
            String sessionId,
            String intent,
            String status,
            String model,
            int stepCount,
            String inputText,
            String outputText,
            String error,
            String createdAt,
            String completedAt,
            String proposalId,
            String proposalStatus
    ) {
    }

    public record AgentStepItem(
            String id,
            int stepIndex,
            String stepType,
            String toolName,
            String status,
            Integer latencyMs,
            Object input,
            Object output,
            String error,
            String createdAt
    ) {
    }

    public record AgentProposalItem(
            String id,
            String title,
            String status,
            Integer baseVersion,
            Object diff,
            Object validation,
            String createdAt,
            String expiresAt,
            String appliedAt
    ) {
    }

    public record AgentRunDetail(
            AgentRunItem run,
            List<AgentStepItem> steps,
            List<AgentProposalItem> proposals
    ) {
    }
}
