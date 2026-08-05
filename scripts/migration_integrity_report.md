# Migration 完整性检查报告

## 检查日期
2025-11-04

## 检查范围
检查 21 个被修改过的 migration 文件所涉及的表结构

## 检查结果总结

### ✅ 完整的表（所有字段和索引都存在）

#### 1. Commands
- ✅ 所有基础字段存在
- ✅ PluginId 字段存在 (varchar(190))
- ✅ 所有索引存在:
  - idx_command_team_id
  - idx_command_update_at
  - idx_command_create_at
  - idx_command_delete_at

#### 2. IncomingWebhooks
- ✅ 所有基础字段存在
- ✅ Username 已扩展为 VARCHAR(255)
- ✅ IconURL 字段存在 (text)
- ✅ ChannelLocked 字段存在 (tinyint(1))
- ✅ Description 已更改为 text
- ✅ 所有索引存在:
  - idx_incoming_webhook_user_id
  - idx_incoming_webhook_team_id
  - idx_incoming_webhook_update_at
  - idx_incoming_webhook_create_at
  - idx_incoming_webhook_delete_at

#### 3. Reactions
- ✅ 所有基础字段存在
- ✅ UpdateAt 字段存在 (bigint(20)) - 已修复
- ✅ DeleteAt 字段存在 (bigint(20)) - 已修复
- ✅ RemoteId 字段存在 (varchar(26)) - 已修复
- ✅ ChannelId 字段存在
- ✅ 主键正确: (PostId, UserId, EmojiName)
- ✅ idx_reactions_channel_id 索引存在

#### 4. Sessions
- ✅ 所有基础字段存在
- ✅ ExpiredNotify 字段存在 (tinyint(1))
- ✅ 所有索引存在:
  - idx_sessions_user_id
  - idx_sessions_token
  - idx_sessions_expires_at
  - idx_sessions_create_at
  - idx_sessions_last_activity_at
- ⚠️ Roles 字段类型为 text（migration 中为 varchar(64)，但实际可能已升级为 text）
- ✅ Props 字段类型为 json（已升级）

#### 5. Preferences
- ✅ 所有基础字段存在
- ✅ Value 字段类型为 text
- ✅ 主键正确: (UserId, Category, Name)
- ✅ 索引存在:
  - idx_preferences_category
  - idx_preferences_name
- ✅ idx_preferences_user_id 已正确删除（因为已包含在主键中）

#### 6. UploadSessions
- ✅ 所有基础字段存在
- ✅ RemoteId 字段存在 (varchar(26))
- ✅ ReqFileId 字段存在 (varchar(26))
- ✅ 所有索引存在:
  - idx_uploadsessions_user_id (正确指向 UserId)
  - idx_uploadsessions_create_at
  - idx_uploadsessions_type

#### 7. Threads
- ✅ 所有基础字段存在
- ✅ ChannelId 字段存在 (VARCHAR(26))
- ✅ idx_threads_channel_id 索引存在 (实际为 idx_threads_channel_id_last_reply_at)
- ✅ Participants 字段类型为 json（已升级）
- ✅ 额外字段: ThreadDeleteAt, ThreadTeamId（来自更新的 migration）

#### 8. UserTermsOfService
- ✅ 表存在
- ✅ 所有字段正确
- ✅ 主键正确: (UserId)
- ✅ idx_user_terms_of_service_user_id 已正确删除

#### 9. Users
- ✅ 所有基础字段存在
- ✅ LastActivityAt 和 LastPingAt 已正确删除
- ✅ Position 字段存在 (varchar(128))
- ✅ Timezone 字段存在 (json)
- ✅ RemoteId 字段存在 (VARCHAR(26))
- ✅ 所有索引存在:
  - idx_users_update_at
  - idx_users_create_at
  - idx_users_delete_at
  - idx_users_all_txt (全文索引)
  - idx_users_all_no_full_name_txt (全文索引)
  - idx_users_names_txt (全文索引)
  - idx_users_names_no_full_name_txt (全文索引)
- ✅ idx_users_email 已正确删除
- ⚠️ Roles 字段类型为 text（migration 中为 varchar(256)，但实际可能已升级为 text）
- ✅ Props, NotifyProps, Timezone 字段类型为 json（已升级）
- ✅ 额外字段: LastLogin, MfaUsedTimestamps（来自更新的 migration）

#### 10. ChannelMembers
- ✅ 所有基础字段存在
- ✅ MentionCountRoot 字段存在 (bigint(20))
- ✅ MsgCountRoot 字段存在 (bigint(20))
- ✅ NotifyProps 字段类型为 json（已升级）
- ✅ Roles 字段类型为 text
- ✅ 额外字段: UrgentMentionCount（来自更新的 migration）

#### 11. Channels
- ✅ 所有基础字段存在
- ✅ TotalMsgCountRoot 字段存在 (bigint(20))
- ✅ LastRootPostAt 字段存在 (bigint(20), DEFAULT 0)
- ✅ BannerInfo 字段类型为 json
- ✅ 额外字段: DefaultCategoryName（来自更新的 migration）

#### 12. PublicChannels
- ✅ 表存在
- ✅ 所有字段正确
- ✅ 索引存在:
  - idx_publicchannels_team_id
  - idx_publicchannels_delete_at
  - idx_publicchannels_search_txt (全文索引)
- ✅ idx_publicchannels_name 已正确删除

#### 13. Posts
- ✅ FileIds 字段类型为 text (已修改)
- ✅ Props 字段类型为 json (已修改)
- ✅ ParentId 字段已正确删除
- ✅ idx_posts_root_id_delete_at 索引存在
- ✅ idx_posts_root_id 索引已正确删除

#### 14. CommandWebhooks
- ✅ ParentId 字段已正确删除
- ✅ RootId 数据已从 ParentId 迁移

### ⚠️ 发现的问题

#### 1. Roles 表
**问题**: Permissions 字段类型不正确
- **当前**: text
- **应该**: longtext
- **影响**: text 类型最大只能存储 65,535 字节，longtext 可以存储 4GB
- **来源**: Migration 000017_create_roles.up.sql (line 55-61)

**修复 SQL**:
```sql
ALTER TABLE Roles MODIFY Permissions longtext;
```

### 📊 字段类型升级说明

以下字段在原始 migration 中定义为基础类型，但在数据库中已升级为更现代的类型（这是正常的）：

1. **JSON 类型升级** (text → json):
   - Sessions.Props
   - Users.Props, NotifyProps, Timezone
   - ChannelMembers.NotifyProps
   - Threads.Participants
   - Posts.Props
   - Channels.BannerInfo

2. **Roles 字段扩展** (varchar → text):
   - Sessions.Roles
   - Users.Roles
   - ChannelMembers.Roles

这些升级是 Mattermost 后续版本的改进，不需要修复。

## 修复建议

只需要修复 1 个问题：

```sql
-- 修复 Roles.Permissions 字段类型
ALTER TABLE Roles MODIFY Permissions longtext;
```

## 验证命令

执行修复后，运行以下命令验证：

```sql
SELECT
    table_name,
    column_name,
    column_type
FROM information_schema.columns
WHERE table_schema = 'mattermost_prod_local'
  AND table_name = 'Roles'
  AND column_name = 'Permissions';
```

期望结果: `column_type = 'longtext'`

## 总结

- **检查的表数量**: 15 个
- **完全正确的表**: 14 个
- **需要修复的表**: 1 个 (Roles)
- **需要执行的 SQL 语句**: 1 条

所有之前报告的 Reactions 表缺失字段问题已经修复完成。目前只剩下 Roles.Permissions 字段类型需要调整。
