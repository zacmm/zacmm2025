// Custom message utility functions
// 客製化訊息工具函數

import {getCurrentUserId} from 'mattermost-redux/selectors/entities/users';

/**
 * 檢查訊息是否為當前用戶所發
 * Check if message is from current user
 */
export function isCurrentUserMessage(post, currentUserId) {
    if (!post || !currentUserId) {
        return false;
    }
    return post.user_id === currentUserId;
}

/**
 * 為 post 元素添加客製化類別
 * Add custom classes to post element
 */
export function getPostCustomClasses(post, currentUserId, state = {}) {
    const classes = ['post'];
    
    // 當前用戶的訊息添加 current-user 類別
    if (isCurrentUserMessage(post, currentUserId)) {
        classes.push('current-user');
    }
    
    // 未讀訊息標記
    if (state.isUnread) {
        classes.push('unread-message');
    }
    
    // 提及當前用戶的訊息
    if (state.mentionsCurrentUser) {
        classes.push('mention-highlight');
    }
    
    // 搜索高亮
    if (state.isSearchHighlight) {
        classes.push('search-highlight');
    }
    
    return classes.join(' ');
}

/**
 * 為側邊欄頻道添加客製化類別
 * Add custom classes to sidebar channel
 */
export function getSidebarChannelClasses(channel, isUnread = false, mentionCount = 0) {
    const classes = ['sidebar-item'];
    
    if (isUnread) {
        classes.push('unread');
    }
    
    if (mentionCount > 0) {
        classes.push('has-mentions');
    }
    
    return classes.join(' ');
}

/**
 * 處理未讀消息置頂邏輯
 * Handle unread messages pinning logic
 */
export function organizeChannelsWithUnreadPinned(channels, unreadChannels = []) {
    if (!Array.isArray(channels) || !Array.isArray(unreadChannels)) {
        return channels;
    }
    
    // 分離已讀和未讀頻道
    const readChannels = channels.filter(channel => 
        !unreadChannels.some(unread => unread.id === channel.id)
    );
    
    // 返回重新組織的頻道列表：未讀在前，已讀在後
    return [
        // 添加未讀區塊標題
        ...(unreadChannels.length > 0 ? [{
            id: 'unread-section-header',
            type: 'unread-header',
            display_name: '未讀消息'
        }] : []),
        ...unreadChannels,
        // 添加其他頻道區塊標題
        ...(readChannels.length > 0 ? [{
            id: 'read-section-header', 
            type: 'read-header',
            display_name: '其他頻道'
        }] : []),
        ...readChannels
    ];
}

/**
 * 文字底框處理
 * Text background/border processing
 */
export function processMessageTextForStyling(messageText) {
    if (!messageText || typeof messageText !== 'string') {
        return messageText;
    }
    
    // 為特殊內容類型添加包裝
    let processedText = messageText;
    
    // 處理 @mentions
    processedText = processedText.replace(
        /@(\w+)/g, 
        '<span class="mention-highlight">@$1</span>'
    );
    
    // 處理 #hashtags  
    processedText = processedText.replace(
        /#(\w+)/g,
        '<span class="hashtag-highlight">#$1</span>'
    );
    
    // 處理程式碼區塊（保持原有的 markdown 處理）
    // 這裡主要是確保自定義樣式能正確應用
    
    return processedText;
}

/**
 * 響應式設計輔助函數
 * Responsive design helper
 */
export function getResponsiveMessageWidth() {
    if (typeof window === 'undefined') {
        return '70%';
    }
    
    const windowWidth = window.innerWidth;
    
    if (windowWidth <= 768) {
        return '85%'; // 手機端
    } else if (windowWidth <= 1024) {
        return '75%'; // 平板端
    } else {
        return '70%'; // 桌面端
    }
}

/**
 * 深色模式檢測
 * Dark mode detection
 */
export function isDarkModeEnabled() {
    if (typeof window === 'undefined') {
        return false;
    }
    
    // 檢查系統偏好
    const prefersDarkMode = window.matchMedia && 
        window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    // 檢查 Mattermost 主題設定（如果可用）
    const mattermostTheme = localStorage.getItem('theme') || 
        document.body.classList.contains('theme--dark');
    
    return prefersDarkMode || mattermostTheme;
}

export default {
    isCurrentUserMessage,
    getPostCustomClasses,
    getSidebarChannelClasses,
    organizeChannelsWithUnreadPinned,
    processMessageTextForStyling,
    getResponsiveMessageWidth,
    isDarkModeEnabled
};