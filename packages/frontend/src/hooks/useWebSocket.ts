import { useEffect, useRef, useCallback } from "react";
import { io, Socket } from "socket.io-client";
import type { TaskEvent } from "../types";

export function useWebSocket(onTaskEvent: (event: TaskEvent) => void) {
  const socketRef = useRef<Socket | null>(null);

  const connect = useCallback(() => {
    const token = localStorage.getItem("token");
    if (!token) return;

    const wsUrl = import.meta.env.PROD
      ? window.location.origin
      : "http://localhost:8000";

    socketRef.current = io(wsUrl, {
      auth: { token },
      transports: ["websocket", "polling"],
    });

    socketRef.current.on("connect", () => {
      console.log("ws connected");
    });

    socketRef.current.on("disconnect", () => {
      console.log("ws disconnected");
    });

    socketRef.current.on("connect_error", (error) => {
      console.error("ws error:", error.message);
    });

    socketRef.current.on("task:update", (event: TaskEvent) => {
      onTaskEvent(event);
    });
  }, [onTaskEvent]);

  const disconnect = useCallback(() => {
    if (socketRef.current) {
      socketRef.current.disconnect();
      socketRef.current = null;
    }
  }, []);

  useEffect(() => {
    connect();
    return () => disconnect();
  }, [connect, disconnect]);

  return {
    socket: socketRef.current,
    reconnect: () => {
      disconnect();
      connect();
    },
  };
}
