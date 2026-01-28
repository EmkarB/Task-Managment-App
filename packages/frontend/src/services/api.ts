import axios from "axios";
import type { User, Task, LoginResponse, TaskListResponse } from "../types";

const getApiUrl = () => {
  // prod ve devde ayni, nginx hallediyo
  return "/api";
};

const api = axios.create({
  baseURL: getApiUrl(),
  headers: {
    "Content-Type": "application/json",
  },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("token");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  },
);

export const authApi = {
  register: async (email: string, password: string) => {
    const response = await api.post("/auth/register", { email, password });
    return response.data;
  },

  login: async (email: string, password: string): Promise<LoginResponse> => {
    const response = await api.post<LoginResponse>("/auth/login", {
      email,
      password,
    });
    return response.data;
  },

  getMe: async (): Promise<User> => {
    const response = await api.get<User>("/auth/me");
    return response.data;
  },
};

export const tasksApi = {
  getAll: async (): Promise<TaskListResponse> => {
    const response = await api.get<TaskListResponse>("/tasks");
    return response.data;
  },

  create: async (
    title: string,
    description?: string,
    status: string = "todo",
  ): Promise<Task> => {
    const response = await api.post<Task>("/tasks", {
      title,
      description,
      status,
    });
    return response.data;
  },

  update: async (
    id: string,
    data: Partial<Pick<Task, "title" | "description" | "status">>,
  ): Promise<Task> => {
    const response = await api.patch<Task>(`/tasks/${id}`, data);
    return response.data;
  },

  delete: async (id: string): Promise<void> => {
    await api.delete(`/tasks/${id}`);
  },
};

export default api;
