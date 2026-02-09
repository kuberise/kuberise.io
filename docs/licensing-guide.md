# Licensing Guide

kuberise.io uses a **dual-licensing** model. The source code is published under the [GNU Affero General Public License v3.0 (AGPL-3.0)](../LICENSE), and a separate [commercial license](../COMMERCIAL_LICENSE.md) is available for organisations that want to use kuberise.io commercially without the AGPL-3.0 copyleft obligations.

This document explains what you can and cannot do, with concrete examples.

---

## What you CAN do without a commercial license

### 1. Read and study the code

Anyone can browse the repository, read the source code, study the Helm charts, and learn from the architecture decisions.

> **Example:** A DevOps engineer browses the kuberise.io GitHub repository to learn how the ArgoCD app-of-apps pattern works, studies the Helm chart structure, and reads the ADRs. No restrictions apply.

### 2. Try it out locally or in a lab

You can install kuberise.io on a local or test cluster to explore and evaluate the platform.

> **Example:** A student spins up a k3d cluster on their laptop, runs `./scripts/install.sh`, and experiments with the platform to learn about Kubernetes, GitOps, and platform engineering. Completely free.

### 3. Use it internally within your own organisation

If you deploy kuberise.io on your own clusters to support your own teams — not as a service you sell to others — no commercial license is needed.

> **Example:** A startup's platform team forks kuberise.io and deploys it on their own AWS EKS clusters to run their internal microservices. They add custom values files for their clusters and enable only the components they need. They do not sell this to anyone; it is their own infrastructure. This is permitted under the AGPL-3.0.

### 4. Modify and contribute back

You can modify the code and submit pull requests. Contributions are licensed under the AGPL-3.0, and by contributing you also grant the project maintainers the right to offer them under a commercial license (see the [CLA section](../COMMERCIAL_LICENSE.md#contributor-license-agreement-cla)).

> **Example:** A developer adds a new chart for a monitoring tool, submits a pull request, and the change is merged into the main repository.

### 5. Fork, modify, and redistribute under AGPL-3.0

You can create your own fork, make changes, and publish or distribute the modified version — as long as you keep it under the AGPL-3.0 license.

> **Example:** A community member forks kuberise.io, adds support for a new CNI plugin, and publishes their fork on GitHub under the same AGPL-3.0 license. Anyone can use their fork under the same terms.

### 6. Use it commercially while fully complying with AGPL-3.0

You can use kuberise.io in a commercial context without a commercial license, provided you fully comply with all AGPL-3.0 obligations — most notably, making the complete source code of any modifications available to every user who interacts with the software over a network.

> **Example:** A consulting company deploys kuberise.io for a client and publishes every modification they made in a public repository under the AGPL-3.0. Because they fully comply with the copyleft obligations, no commercial license is needed.

---

## What you CANNOT do without a commercial license

The following scenarios require a commercial license because they involve generating revenue from kuberise.io while keeping modifications proprietary (i.e., not complying with the AGPL-3.0 copyleft obligations).

### 7. Sell it as a managed or hosted service without sharing source

If you offer kuberise.io (or a modified version) as a hosted platform to paying customers and do not release your modifications, you need a commercial license.

> **Example:** A cloud company takes kuberise.io, adds custom dashboards and automation, and offers "Managed Kubernetes Platform as a Service" to customers for a monthly fee. They do not release their modifications as open source. **A commercial license is required.**

### 8. Consulting or professional services with proprietary modifications

If you deploy kuberise.io for clients as part of paid work and keep your customisations closed-source, you need a commercial license.

> **Example:** A DevOps consulting firm deploys kuberise.io for 20 different enterprise clients. For each client they add custom integrations, scripts, and configurations. They keep all of these modifications proprietary and do not share the source code. **A commercial license is required.**

### 9. Embed it in a proprietary product

If you bundle kuberise.io into a product you sell and do not release the source under AGPL-3.0, you need a commercial license.

> **Example:** A software vendor builds a "Kubernetes Management Suite" product. Under the hood it uses kuberise.io for the platform layer. They sell licences to this product but do not release the source code under the AGPL-3.0. **A commercial license is required.**

### 10. Run it as part of a SaaS without offering source to users

Under AGPL-3.0 Section 13, users who interact with the software over a network have the right to receive the source code. If you run a SaaS that uses kuberise.io and refuse to provide the source, you need a commercial license.

> **Example:** A company builds a SaaS developer portal. Behind the scenes it runs kuberise.io with custom modifications for multi-tenancy and billing. Users interact with it over the web, but the company does not offer the modified source code to those users. **A commercial license is required.**

### 11. Remove the license or re-license the code

You cannot strip the AGPL-3.0 notice and redistribute the code under a different license without a commercial license granting those rights.

> **Example:** Someone takes the kuberise.io code, removes the AGPL-3.0 notice, and publishes it under MIT or a proprietary license. **This is not allowed without a commercial license.**

---

## Quick reference table

| Scenario | Commercial license needed? |
|---|---|
| Read or study the code | No |
| Try on a local or lab cluster | No |
| Use internally within your own organisation | No |
| Modify and contribute back (open source) | No |
| Fork and redistribute under AGPL-3.0 | No |
| Commercial use with full AGPL-3.0 compliance (all modifications open-sourced) | No |
| Sell as a managed service without sharing source | **Yes** |
| Consulting with proprietary modifications | **Yes** |
| Embed in a proprietary product | **Yes** |
| SaaS without offering source to users | **Yes** |
| Re-license under a different license | **Yes** |

---

## The bottom line

**If you make money from kuberise.io and want to keep your modifications closed-source, you need a commercial license. If you are willing to open-source everything under the AGPL-3.0, you do not.**

## Contact

To enquire about a commercial license, reach out to us:

- **Email:** license@kuberise.io
- **Website:** [kuberise.io](https://kuberise.io)
