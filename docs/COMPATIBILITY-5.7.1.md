# 5.7.1 - Visible group compatibility

Uses currentUser.visibleGroups instead of the deprecated groups getter. In the verified Discourse2026.10 core, groups returns visibleGroups, so this preserves the existing menu visibility behavior. It does not claim full group membership or replace server authorization.52 regression checks pass, including a getter that throws if deprecated groups is read. Independent source review accepted. No settings or destinations changed. This warning cleanup is separate from the unproven AI1.6.2 outage cause.
