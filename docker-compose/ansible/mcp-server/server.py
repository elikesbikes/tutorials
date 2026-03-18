import os
import json
import re
import httpx
from mcp.server.fastmcp import FastMCP

SEMAPHORE_URL = os.environ.get("SEMAPHORE_URL", "http://semaphore:3000")
SEMAPHORE_ADMIN = os.environ.get("SEMAPHORE_ADMIN", "admin")
SEMAPHORE_PASS = os.environ.get("SEMAPHORE_PASS", "")

mcp = FastMCP("ansible", host="0.0.0.0", port=8765)


async def semaphore_client() -> httpx.AsyncClient:
    """Return an authenticated httpx client."""
    client = httpx.AsyncClient(base_url=SEMAPHORE_URL, timeout=30)
    resp = await client.post(
        "/api/auth/login",
        json={"auth": SEMAPHORE_ADMIN, "password": SEMAPHORE_PASS},
    )
    if resp.status_code != 204:
        raise RuntimeError(f"Semaphore login failed: {resp.status_code}")
    return client


@mcp.tool()
async def list_projects() -> str:
    """List all Ansible projects in Semaphore."""
    async with await semaphore_client() as c:
        r = await c.get("/api/projects")
        projects = r.json()
        return json.dumps(
            [{"id": p["id"], "name": p["name"], "created": p["created"]} for p in projects],
            indent=2,
        )


@mcp.tool()
async def list_playbook_templates(project_id: int = 1) -> str:
    """List available playbook templates in a project.

    Args:
        project_id: Semaphore project ID (default 1)
    """
    async with await semaphore_client() as c:
        r = await c.get(f"/api/project/{project_id}/templates")
        templates = r.json()
        return json.dumps(
            [
                {
                    "id": t["id"],
                    "name": t["name"],
                    "playbook": t["playbook"],
                    "inventory_id": t["inventory_id"],
                    "last_status": t.get("last_task", {}).get("status") if t.get("last_task") else None,
                }
                for t in templates
            ],
            indent=2,
        )


@mcp.tool()
async def run_playbook(template_id: int, project_id: int = 1, limit: str = "", dry_run: bool = False) -> str:
    """Trigger an Ansible playbook run.

    Args:
        template_id: ID of the template/playbook to run
        project_id: Semaphore project ID (default 1)
        limit: Optional host limit (e.g. 'docker-prod-1.home.elikesbikes.com' or 'prod')
        dry_run: If True, run in check mode without making changes
    """
    payload = {
        "template_id": template_id,
        "debug": False,
        "dry_run": dry_run,
        "diff": False,
        "playbook": "",
        "environment": "{}",
        "limit": limit,
    }
    async with await semaphore_client() as c:
        r = await c.post(f"/api/project/{project_id}/tasks", json=payload)
        if r.status_code not in (200, 201):
            return f"Error: {r.status_code} {r.text}"
        task = r.json()
        return json.dumps(
            {"task_id": task["id"], "status": task["status"], "message": "Playbook queued successfully"},
            indent=2,
        )


@mcp.tool()
async def get_job_status(task_id: int, project_id: int = 1) -> str:
    """Get the status and output of an Ansible task run.

    Args:
        task_id: The task ID returned by run_playbook
        project_id: Semaphore project ID (default 1)
    """
    async with await semaphore_client() as c:
        r = await c.get(f"/api/project/{project_id}/tasks/{task_id}")
        task = r.json()
        output_r = await c.get(f"/api/project/{project_id}/tasks/{task_id}/output")
        output_lines = output_r.json() if output_r.status_code == 200 else []
        log = "\n".join(o.get("output", "") for o in output_lines if o.get("output"))
        return json.dumps(
            {
                "task_id": task["id"],
                "status": task["status"],
                "playbook": task.get("tpl_playbook", ""),
                "started": task.get("start"),
                "ended": task.get("end"),
                "output": log[-3000:] if log else "(no output yet)",
            },
            indent=2,
        )


@mcp.tool()
async def list_recent_jobs(project_id: int = 1, limit: int = 20) -> str:
    """List recent Ansible task runs with their status.

    Args:
        project_id: Semaphore project ID (default 1)
        limit: Number of recent tasks to return (default 20)
    """
    async with await semaphore_client() as c:
        r = await c.get(f"/api/project/{project_id}/tasks?limit={limit}")
        tasks = r.json()
        return json.dumps(
            [
                {
                    "id": t["id"],
                    "playbook": t.get("tpl_playbook") or t.get("tpl_alias"),
                    "status": t["status"],
                    "started": t.get("start"),
                    "ended": t.get("end"),
                    "user": t.get("user_name"),
                }
                for t in tasks
            ],
            indent=2,
        )


@mcp.tool()
async def list_inventory(project_id: int = 1) -> str:
    """List inventories and their hosts for a project.

    Args:
        project_id: Semaphore project ID (default 1)
    """
    async with await semaphore_client() as c:
        r = await c.get(f"/api/project/{project_id}/inventory")
        inventories = r.json()
        return json.dumps(
            [
                {
                    "id": inv["id"],
                    "name": inv["name"],
                    "type": inv["type"],
                    "hosts": inv.get("inventory", ""),
                }
                for inv in inventories
            ],
            indent=2,
        )


@mcp.tool()
async def add_host(hostname: str, group: str, inventory_id: int = 1, project_id: int = 1) -> str:
    """Add a host to an existing inventory group.

    Args:
        hostname: FQDN or IP of the host to add (e.g. 'docker-prod-5.home.elikesbikes.com')
        group: Inventory group to add the host to (e.g. 'prod', 'dev', 'cloud-prod')
        inventory_id: Semaphore inventory ID (default 1 = HomeLab)
        project_id: Semaphore project ID (default 1)
    """
    async with await semaphore_client() as c:
        r = await c.get(f"/api/project/{project_id}/inventory/{inventory_id}")
        if r.status_code != 200:
            return f"Error fetching inventory: {r.status_code}"
        inv = r.json()
        ini = inv.get("inventory", "")

        if hostname in ini:
            return f"Host '{hostname}' already exists in inventory '{inv['name']}'"

        group_pattern = re.compile(rf"^\[{re.escape(group)}\]\s*$", re.MULTILINE)
        if group_pattern.search(ini):
            next_group = re.compile(r"\n\[", re.MULTILINE)
            match = group_pattern.search(ini)
            insert_at = match.end()
            rest = ini[insert_at:]
            next_match = next_group.search(rest)
            if next_match:
                ini = ini[:insert_at] + "\n" + hostname + rest[: next_match.start()] + rest[next_match.start() :]
            else:
                ini = ini.rstrip() + "\n" + hostname + "\n"
        else:
            ini = ini.rstrip() + f"\n\n[{group}]\n{hostname}\n"

        payload = {
            "id": inv["id"],
            "name": inv["name"],
            "project_id": project_id,
            "inventory": ini,
            "ssh_key_id": inv["ssh_key_id"],
            "become_key_id": inv.get("become_key_id"),
            "type": inv["type"],
        }
        put_r = await c.put(f"/api/project/{project_id}/inventory/{inventory_id}", json=payload)
        if put_r.status_code != 204:
            return f"Error updating inventory: {put_r.status_code} {put_r.text}"
        return f"Host '{hostname}' added to group '[{group}]' in inventory '{inv['name']}'"


if __name__ == "__main__":
    mcp.run(transport="sse")
