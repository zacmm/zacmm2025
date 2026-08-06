// License utility functions to check feature availability

export function hasCustomProfileAttributes(license) {
    if (!license) {
        return false;
    }
    
    // Check if license includes custom profile attributes
    return license.IsLicensed === 'true' && 
           license.Features && 
           license.Features.CustomProfileAttributes === 'true';
}

export function shouldFetchCustomProfileAttributes(config, license) {
    // Only fetch if the feature is enabled and licensed
    const isEnabled = config?.ServiceSettings?.EnableCustomProfileAttributes === true;
    const isLicensed = hasCustomProfileAttributes(license);
    
    return isEnabled && isLicensed;
}

// Add this check before making the API call
export function checkEnterpriseFeature(featureName, license) {
    const enterpriseFeatures = [
        'CustomProfileAttributes',
        'LDAP',
        'SAML',
        'Cluster',
        'DataRetention',
        'MessageExport',
        'Elasticsearch'
    ];
    
    if (enterpriseFeatures.includes(featureName)) {
        return license?.Features?.[featureName] === 'true';
    }
    
    return true; // Non-enterprise features are always available
}