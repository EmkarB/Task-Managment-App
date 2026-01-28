import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";
import { useWebSocket } from "../hooks/useWebSocket";
import { tasksApi } from "../services/api";
import type { Task, TaskEvent } from "../types";
import "./Tasks.css";

type TaskStatus = "todo" | "in_progress" | "done";

const STATUS_LABELS: Record<TaskStatus, string> = {
  todo: "To Do",
  in_progress: "In Progress",
  done: "Done",
};

const STATUS_ORDER: TaskStatus[] = ["todo", "in_progress", "done"];

export function Tasks() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [newTitle, setNewTitle] = useState("");
  const [newDescription, setNewDescription] = useState("");
  const [creating, setCreating] = useState(false);

  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const [editTitle, setEditTitle] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editStatus, setEditStatus] = useState<TaskStatus>("todo");

  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const fetchTasks = useCallback(async () => {
    try {
      const response = await tasksApi.getAll();
      setTasks(response.tasks);
      setError(null);
    } catch {
      setError("Failed to fetch tasks");
    } finally {
      setLoading(false);
    }
  }, []);

  const handleTaskEvent = useCallback(
    (_: TaskEvent) => {
      fetchTasks();
    },
    [fetchTasks],
  );

  useWebSocket(handleTaskEvent);

  useEffect(() => {
    fetchTasks();
  }, [fetchTasks]);

  const handleCreateTask = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;

    setCreating(true);
    try {
      await tasksApi.create(newTitle, newDescription || undefined);
      setNewTitle("");
      setNewDescription("");
    } catch {
      setError("Failed to create task");
    } finally {
      setCreating(false);
    }
  };

  const handleUpdateTask = async () => {
    if (!editingTask) return;

    try {
      await tasksApi.update(editingTask.id, {
        title: editTitle,
        description: editDescription || undefined,
        status: editStatus,
      });
      setEditingTask(null);
    } catch {
      setError("Failed to update task");
    }
  };

  const handleDeleteTask = async (taskId: string) => {
    if (!confirm("Are you sure you want to delete this task?")) return;

    try {
      await tasksApi.delete(taskId);
    } catch {
      setError("Failed to delete task");
    }
  };

  const handleStatusChange = async (task: Task, newStatus: TaskStatus) => {
    try {
      await tasksApi.update(task.id, { status: newStatus });
    } catch {
      setError("Failed to update task status");
    }
  };

  const openEditModal = (task: Task) => {
    setEditingTask(task);
    setEditTitle(task.title);
    setEditDescription(task.description || "");
    setEditStatus(task.status);
  };

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  if (loading) {
    return (
      <div className="tasks-container">
        <div className="loading">Loading tasks...</div>
      </div>
    );
  }

  const tasksByStatus = STATUS_ORDER.reduce(
    (acc, status) => {
      acc[status] = tasks.filter((t) => t.status === status);
      return acc;
    },
    {} as Record<TaskStatus, Task[]>,
  );

  return (
    <div className="tasks-container">
      <header className="tasks-header">
        <div className="header-left">
          <h1>Task Manager</h1>
          <span className="user-email">{user?.email}</span>
        </div>
        <button className="logout-btn" onClick={handleLogout}>
          Logout
        </button>
      </header>

      {error && (
        <div className="error-banner">
          {error}
          <button onClick={() => setError(null)}>×</button>
        </div>
      )}

      <form className="create-task-form" onSubmit={handleCreateTask}>
        <div className="form-row">
          <input
            type="text"
            placeholder="Task title..."
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            required
          />
          <input
            type="text"
            placeholder="Description (optional)"
            value={newDescription}
            onChange={(e) => setNewDescription(e.target.value)}
          />
          <button type="submit" disabled={creating || !newTitle.trim()}>
            {creating ? "Adding..." : "Add Task"}
          </button>
        </div>
      </form>

      <div className="task-board">
        {STATUS_ORDER.map((status) => (
          <div key={status} className={`task-column ${status}`}>
            <div className="column-header">
              <h2>{STATUS_LABELS[status]}</h2>
              <span className="task-count">{tasksByStatus[status].length}</span>
            </div>
            <div className="task-list">
              {tasksByStatus[status].map((task) => (
                <div key={task.id} className="task-card">
                  <div className="task-content">
                    <h3>{task.title}</h3>
                    {task.description && <p>{task.description}</p>}
                  </div>
                  <div className="task-actions">
                    <select
                      value={task.status}
                      onChange={(e) =>
                        handleStatusChange(task, e.target.value as TaskStatus)
                      }
                    >
                      {STATUS_ORDER.map((s) => (
                        <option key={s} value={s}>
                          {STATUS_LABELS[s]}
                        </option>
                      ))}
                    </select>
                    <button
                      className="edit-btn"
                      onClick={() => openEditModal(task)}
                    >
                      Edit
                    </button>
                    <button
                      className="delete-btn"
                      onClick={() => handleDeleteTask(task.id)}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
              {tasksByStatus[status].length === 0 && (
                <div className="empty-column">No tasks</div>
              )}
            </div>
          </div>
        ))}
      </div>

      {editingTask && (
        <div className="modal-overlay" onClick={() => setEditingTask(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>Edit Task</h2>
            <div className="modal-form">
              <div className="form-group">
                <label>Title</label>
                <input
                  type="text"
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                />
              </div>
              <div className="form-group">
                <label>Description</label>
                <textarea
                  value={editDescription}
                  onChange={(e) => setEditDescription(e.target.value)}
                  rows={3}
                />
              </div>
              <div className="form-group">
                <label>Status</label>
                <select
                  value={editStatus}
                  onChange={(e) => setEditStatus(e.target.value as TaskStatus)}
                >
                  {STATUS_ORDER.map((s) => (
                    <option key={s} value={s}>
                      {STATUS_LABELS[s]}
                    </option>
                  ))}
                </select>
              </div>
              <div className="modal-actions">
                <button
                  className="cancel-btn"
                  onClick={() => setEditingTask(null)}
                >
                  Cancel
                </button>
                <button className="save-btn" onClick={handleUpdateTask}>
                  Save Changes
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
