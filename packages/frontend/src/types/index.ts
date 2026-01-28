export interface User {
  id: string;
  email: string;
  created_at: string;
}

export interface Task {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  status: 'todo' | 'in_progress' | 'done';
  created_at: string;
  updated_at: string;
}

export interface TaskEvent {
  type: 'task.created' | 'task.updated' | 'task.deleted';
  taskId: string;
  timestamp: number;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
}

export interface TaskListResponse {
  tasks: Task[];
  count: number;
}
