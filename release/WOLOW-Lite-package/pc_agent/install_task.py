"""Register the WOLOW agent as a single-instance Windows boot task."""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path
from xml.etree import ElementTree as ET

TASK_NAMESPACE = "http://schemas.microsoft.com/windows/2004/02/mit/task"
ET.register_namespace("", TASK_NAMESPACE)


def tag(name: str) -> str:
    return f"{{{TASK_NAMESPACE}}}{name}"


def task_xml(python_exe: Path, agent_script: Path) -> bytes:
    """Build a Task Scheduler definition with explicit recovery semantics."""
    task = ET.Element(tag("Task"), {"version": "1.4"})
    registration = ET.SubElement(task, tag("RegistrationInfo"))
    ET.SubElement(registration, tag("Description")).text = "WOLOW Lite PC Agent - background network service"
    triggers = ET.SubElement(task, tag("Triggers"))
    boot_trigger = ET.SubElement(triggers, tag("BootTrigger"))
    ET.SubElement(boot_trigger, tag("Enabled")).text = "true"
    settings = ET.SubElement(task, tag("Settings"))
    for name, value in {"MultipleInstancesPolicy": "IgnoreNew", "DisallowStartIfOnBatteries": "false", "StopIfGoingOnBatteries": "false", "AllowHardTerminate": "true", "StartWhenAvailable": "true", "RunOnlyIfNetworkAvailable": "false", "AllowStartOnDemand": "true", "Enabled": "true", "Hidden": "true", "ExecutionTimeLimit": "PT0S", "Priority": "7"}.items():
        ET.SubElement(settings, tag(name)).text = value
    restart = ET.SubElement(settings, tag("RestartOnFailure"))
    ET.SubElement(restart, tag("Interval")).text = "PT1M"
    ET.SubElement(restart, tag("Count")).text = "3"
    actions = ET.SubElement(task, tag("Actions"))
    execute = ET.SubElement(actions, tag("Exec"))
    ET.SubElement(execute, tag("Command")).text = str(python_exe)
    ET.SubElement(execute, tag("Arguments")).text = f'"{agent_script}"'
    ET.SubElement(execute, tag("WorkingDirectory")).text = str(agent_script.parent)
    return ET.tostring(task, encoding="utf-16", xml_declaration=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-name", required=True)
    parser.add_argument("--python", required=True, type=Path)
    parser.add_argument("--agent", required=True, type=Path)
    args = parser.parse_args()
    python_exe, agent_script = args.python.resolve(), args.agent.resolve()
    if not python_exe.is_file():
        parser.error(f"Python executable does not exist: {python_exe}")
    if not agent_script.is_file():
        parser.error(f"Agent script does not exist: {agent_script}")
    with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as task_file:
        task_path = Path(task_file.name)
        task_file.write(task_xml(python_exe, agent_script))
    try:
        completed = subprocess.run(
            ["schtasks", "/create", "/tn", args.task_name, "/xml", str(task_path), "/ru", "SYSTEM", "/f"],
            check=False,
        )
    finally:
        task_path.unlink(missing_ok=True)
    if completed.returncode:
        return completed.returncode
    print(f"      Registered task: {args.task_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
