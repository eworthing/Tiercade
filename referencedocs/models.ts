/* models.ts - TypeScript interfaces for TierList schema */
export type JSONValue = string | number | boolean | null | JSONValue[] | { [key: string]: JSONValue };

export interface Audit {
  createdAt: string;
  updatedAt: string;
  createdBy?: string;
  updatedBy?: string;
  [key: string]: JSONValue;
}

export interface Media {
  id: string;
  kind: "image" | "gif" | "video" | "audio";
  uri: string;
  mime: string;
  w?: number;
  h?: number;
  durationMs?: number;
  posterUri?: string;
  thumbUri?: string;
  alt?: string;
  attribution?: { creator?: string; license?: string; source?: string; [key: string]: JSONValue };
  [key: string]: JSONValue;
}

export interface SourceLink {
  rel?: string;
  href: string;
  title?: string;
  [key: string]: JSONValue;
}

export interface Item {
  id: string;
  title: string;
  subtitle?: string;
  summary?: string;
  slug?: string;
  media?: Media[];
  attributes?: { [key: string]: string | number | boolean | string[] };
  tags?: string[];
  rating?: number;
  sources?: SourceLink[];
  locale?: { [locale: string]: { [field: string]: string } };
  meta?: Audit;
  [key: string]: JSONValue;
}

export interface ItemOverride {
  displayTitle?: string;
  notes?: string;
  tags?: string[];
  rating?: number;
  media?: Media[];
  hidden?: boolean;
  [key: string]: JSONValue;
}

export interface Tier {
  id: string;
  label: string;
  color?: string;
  order: number;
  locked?: boolean;
  collapsed?: boolean;
  rules?: { [key: string]: JSONValue };
  itemIds: string[];
  [key: string]: JSONValue;
}

export interface Links {
  visibility?: "public" | "unlisted" | "private";
  shareUrl?: string;
  embedHtml?: string;
  stateUrl?: string;
  [key: string]: JSONValue;
}

export interface Settings {
  theme?: "light" | "dark" | "system";
  tierSortOrder?: "S-F" | "F-S";
  gridSnap?: boolean;
  showUnranked?: boolean;
  accessibility?: { colorblind?: boolean; highContrast?: boolean };
  [key: string]: JSONValue;
}

export interface Member { userId: string; role: "owner" | "editor" | "viewer"; [key: string]: JSONValue; }
export interface Collaboration { members?: Member[]; [key: string]: JSONValue; }

export interface Project {
  schemaVersion: number;
  projectId: string;
  title?: string;
  description?: string;
  tiers: Tier[];
  items: { [itemId: string]: Item };
  overrides?: { [itemId: string]: ItemOverride };
  links?: Links;
  settings?: Settings;
  collab?: Collaboration;
  audit: Audit;
  [key: string]: JSONValue;
}