# Issue Response Plan

This document outlines the procedure for dealing with any security issues the arise related to the Hummingbird package and its associated libraries.

## Communication

All communication throughout this process, except for public announcements should happen exclusively through private channels. Not through public issues, PRs or public Discord Channels.

Use the **private Github Security Advisory thread** for communication with the reporter.

## Response Process

### Triage

Acknowledge receipt of report within 5 working days.

Read the report and validate vulnerability exists. If a PoC (Proof of Concept) is provided, verify it demonstrates the vulnerability.

Determine whether the vulnerability is in Hummingbird, if not report upstream to relevant parties.

### Scope

Identify the release of the library where this vulnerability was introduced.

Determine the severity/impact of the issue.
- Does the vulnerability expose confidential data, provide potential for denial of service attacks.
- Ease of replication: does it require precise timing, a significant number of steps, or a specific configuration.
- Is the vulnerability actively being exploited?
- Use the [CVSS 4.0](https://www.first.org/cvss/v4.0/specification-document) base score as a guide.

Supply-chain and CI/CD incidents are always treated as **Critical** regardless of CVSS.

### Mitigate

1. Report to [SSWG](https://www.swift.org/sswg/security/) (Swift Server Working Group)
2. Use a private repo, or private pull request via GitHub advisory reporting to generate a patch.
3. Ask the reporter to verify patch
4. Alert important and trusted adopters
5. Prepare advisory
    - Title: {Affected package} {version vulnerability is fixed in} {description}
    - Summary: Summary of vulnerability, What versions are impacted, severity
    - Details: More detailed description of vulnerability
    - Timeline
    - Acknowledge reporter

### Remediation and Disclosure

- Merge pull request and release versions of affected library with fix included. Security fixes are only applied to the **latest** stable releases of Hummingbird. End users will be required to upgrade to latest once a release is made. 
- Release CVE advisory.
- Report on [Swift Forums](https://forums.swift.org/c/server/security-updates/) and Hummingbird Discord.

## Learn

- How was the vunerability introduced? 
- What could we have done to prevent it?
- Is there anything we can to ensure it doesn't happen again.
- What did we do well during the process?
- What could be improved in the process?