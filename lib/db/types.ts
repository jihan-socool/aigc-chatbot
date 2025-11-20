// Database types for client-side use
// This file contains only type definitions to prevent importing server code

export type {
  User,
  Chat,
  DBMessage,
  Document,
  Suggestion,
  Vote,
  Stream,
} from "./schema";

export type { ArtifactKind } from "@/components/artifact";
export type { VisibilityType } from "@/components/visibility-selector";