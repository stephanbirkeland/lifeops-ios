function OnLoad(executionContext) {
    if (!executionContext) {
        console.error("OnLoad: executionContext is required");
        return;
    }

    try {
        const formContext = executionContext.getFormContext();
        const currentUserId = Xrm.Utility.getGlobalContext().userSettings.userId;
        const userReferenceField = formContext.getAttribute("nf_user_reference_field");
        const targetField = formContext.getControl("nf_target_field");

        const referencedUser = userReferenceField.getValue();

        // Hide field by default
        if (!referencedUser?.length) {
            targetField.setVisible(false);
            return;
        }

        const referencedUserId = referencedUser[0]?.id;
        if (!referencedUserId) {
            targetField.setVisible(false);
            return;
        }

        // Show field only if referenced user matches current user
        const isCurrentUser = referencedUserId.toLowerCase().replace(/[{}]/g, '') ===
                             currentUserId.toLowerCase().replace(/[{}]/g, '');

        targetField.setVisible(isCurrentUser);

    } catch (error) {
        console.error("OnLoad error:", error.message);
    }
}