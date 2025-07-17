#!/bin/bash

# Script to add cross-references to all repository README files
# This ensures all repositories reference and align with each other

REPOS=(
    "19-trillion-solution"
    "ChaseWhiteRabbit"
    "company-intranet"
    "grieftodesign"
    "TiaAstor"
    "tiation"
    "server-configs-gae"
    "ProtectChildrenAustralia"
    "home"
    "git-workspace"
    "dontbeacunt"
    "DiceRollerSimulator"
    "core-foundation-rs"
    "Case_Study_Legal"
    "awesome-decentralized-autonomous-organizations"
    "AlmaStreet"
    "ubuntu-dev-setup"
    "windows-dev-setup"
    "workflows"
)

# Function to add cross-reference section to README
add_cross_references() {
    local repo=$1
    local readme_path="/Users/tiaastor/tiation-github/$repo/README.md"
    
    # Check if README exists
    if [ ! -f "$readme_path" ]; then
        echo "Creating README for $repo..."
        touch "$readme_path"
    fi
    
    # Check if cross-references already exist
    if grep -q "## Related Repositories" "$readme_path" 2>/dev/null; then
        echo "Cross-references already exist in $repo/README.md"
        return
    fi
    
    echo "Adding cross-references to $repo/README.md..."
    
    # Add cross-reference section
    cat >> "$readme_path" << 'EOF'

## Related Repositories

This repository is part of the Tiation GitHub ecosystem. For a complete overview of all repositories and their relationships, see the [Repository Index](../REPOSITORY_INDEX.md).

### Direct Dependencies
EOF

    # Add specific relationships based on the repository
    case "$repo" in
        "19-trillion-solution")
            cat >> "$readme_path" << 'EOF'
- [company-intranet](../company-intranet/) - Internal portal implementation
- [RiggerConnect-RiggerJobs-Workspace-PB](../RiggerConnect-RiggerJobs-Workspace-PB/) - Industry-specific solution
- [server-configs-gae](../server-configs-gae/) - Deployment configurations
- [workflows](../workflows/) - CI/CD pipelines
EOF
            ;;
        "company-intranet")
            cat >> "$readme_path" << 'EOF'
- [19-trillion-solution](../19-trillion-solution/) - Parent solution framework
- [workflows](../workflows/) - CI/CD pipelines
- [server-configs-gae](../server-configs-gae/) - Infrastructure configs
EOF
            ;;
        "ChaseWhiteRabbit")
            cat >> "$readme_path" << 'EOF'
- [grieftodesign](../grieftodesign/) - Creative design collaboration
- [core-foundation-rs](../core-foundation-rs/) - Core Rust libraries
EOF
            ;;
        "grieftodesign")
            cat >> "$readme_path" << 'EOF'
- [TiaAstor](../TiaAstor/) - Portfolio showcase
- [ChaseWhiteRabbit](../ChaseWhiteRabbit/) - Interactive storytelling project
EOF
            ;;
        "git-workspace")
            cat >> "$readme_path" << 'EOF'
- [ubuntu-dev-setup](../ubuntu-dev-setup/) - Ubuntu development environment
- [windows-dev-setup](../windows-dev-setup/) - Windows development environment
- [workflows](../workflows/) - GitHub Actions workflows
EOF
            ;;
        "ubuntu-dev-setup"|"windows-dev-setup")
            cat >> "$readme_path" << 'EOF'
- [git-workspace](../git-workspace/) - Git workflow tools
- [workflows](../workflows/) - Automation workflows
- [server-configs-gae](../server-configs-gae/) - Server configurations
EOF
            ;;
        "workflows")
            cat >> "$readme_path" << 'EOF'
- Used by all repositories for CI/CD
- [git-workspace](../git-workspace/) - Git automation tools
- [server-configs-gae](../server-configs-gae/) - Deployment targets
EOF
            ;;
        "DiceRollerSimulator")
            cat >> "$readme_path" << 'EOF'
- [core-foundation-rs](../core-foundation-rs/) - Rust foundation libraries
EOF
            ;;
        "core-foundation-rs")
            cat >> "$readme_path" << 'EOF'
- [DiceRollerSimulator](../DiceRollerSimulator/) - Dice simulation implementation
- [ChaseWhiteRabbit](../ChaseWhiteRabbit/) - Interactive experience engine
EOF
            ;;
        "ProtectChildrenAustralia")
            cat >> "$readme_path" << 'EOF'
- [Case_Study_Legal](../Case_Study_Legal/) - Legal framework and templates
- [AlmaStreet](../AlmaStreet/) - Community initiatives
- [dontbeacunt](../dontbeacunt/) - Online safety campaign
EOF
            ;;
        "Case_Study_Legal")
            cat >> "$readme_path" << 'EOF'
- [ProtectChildrenAustralia](../ProtectChildrenAustralia/) - Child protection implementation
- [awesome-decentralized-autonomous-organizations](../awesome-decentralized-autonomous-organizations/) - DAO legal structures
EOF
            ;;
        "awesome-decentralized-autonomous-organizations")
            cat >> "$readme_path" << 'EOF'
- [Case_Study_Legal](../Case_Study_Legal/) - Legal frameworks
- [19-trillion-solution](../19-trillion-solution/) - Enterprise implementation
EOF
            ;;
        "TiaAstor")
            cat >> "$readme_path" << 'EOF'
- [grieftodesign](../grieftodesign/) - Design projects
- [tiation](../tiation/) - Main organization
- Links to all major projects
EOF
            ;;
        "tiation")
            cat >> "$readme_path" << 'EOF'
- Parent organization for all repositories
- [TiaAstor](../TiaAstor/) - Personal portfolio
- [19-trillion-solution](../19-trillion-solution/) - Business solutions
EOF
            ;;
        "home")
            cat >> "$readme_path" << 'EOF'
- [ubuntu-dev-setup](../ubuntu-dev-setup/) - Ubuntu configurations
- [windows-dev-setup](../windows-dev-setup/) - Windows configurations
EOF
            ;;
        "server-configs-gae")
            cat >> "$readme_path" << 'EOF'
- [19-trillion-solution](../19-trillion-solution/) - Main deployment target
- [company-intranet](../company-intranet/) - Intranet deployment
- [workflows](../workflows/) - Deployment automation
EOF
            ;;
        "AlmaStreet")
            cat >> "$readme_path" << 'EOF'
- [ProtectChildrenAustralia](../ProtectChildrenAustralia/) - Child safety initiatives
EOF
            ;;
        "dontbeacunt")
            cat >> "$readme_path" << 'EOF'
- [ProtectChildrenAustralia](../ProtectChildrenAustralia/) - Online safety advocacy
EOF
            ;;
    esac
    
    # Add common footer
    cat >> "$readme_path" << 'EOF'

### Quick Links
- [Repository Index](../REPOSITORY_INDEX.md) - Complete repository overview
- [Development Setup](../ubuntu-dev-setup/README.md) - Development environment setup
- [Workflows](../workflows/) - CI/CD templates
- [Infrastructure](../server-configs-gae/) - Deployment configurations

---
*Part of the [Tiation](../tiation/) ecosystem*
EOF
    
    echo "✓ Updated $repo/README.md"
}

# Main execution
echo "Adding cross-references to all repository README files..."
echo "================================================"

for repo in "${REPOS[@]}"; do
    if [ -d "/Users/tiaastor/tiation-github/$repo" ]; then
        add_cross_references "$repo"
    else
        echo "⚠ Repository $repo not found, skipping..."
    fi
done

echo "================================================"
echo "Cross-reference update complete!"
echo ""
echo "Next steps:"
echo "1. Review the changes in each repository"
echo "2. Commit the changes to each repository"
echo "3. Push to remote repositories"
