// file: .ts - pure logic. Ports of Contributor / GitHubRepo (SwiftRadio/Networking/NetworkService.swift:19-36)
// and LibrariesViewController.LibraryInfo (SwiftRadio/ViewControllers/LibrariesViewController.swift:16).

// Wire shape of one GitHub /contributors element (CodingKeys: avatar_url, html_url).
export interface ContributorJson {
  login: string;
  avatar_url: string;
  html_url: string;
  contributions: number;
}

export interface GitHubRepoJson {
  name: string;
  description?: string | null;
}

export class Contributor {
  login: string = '';
  avatarURL: string = '';
  htmlURL: string = '';
  contributions: number = 0;

  static fromJson(j: ContributorJson): Contributor {
    const c: Contributor = new Contributor();
    c.login = j.login;
    c.avatarURL = j.avatar_url;
    c.htmlURL = j.html_url;
    c.contributions = j.contributions;
    return c;
  }
}

export class GitHubRepo {
  name: string = '';
  description?: string;

  static fromJson(j: GitHubRepoJson): GitHubRepo {
    const r: GitHubRepo = new GitHubRepo();
    r.name = j.name;
    r.description = (j.description === null || j.description === undefined) ? undefined : j.description;
    return r;
  }
}

export class LibraryInfo {
  owner: string;
  repo: string;
  // Empty until fetched; the row shows "owner/repo" while empty (source cellForRowAt).
  name: string;
  // undefined -> the row shows Content.Common.noDescription.
  description?: string;

  constructor(owner: string, repo: string, name: string = '', description?: string) {
    this.owner = owner;
    this.repo = repo;
    this.name = name;
    this.description = description;
  }

  get htmlURL(): string {
    return `https://github.com/${this.owner}/${this.repo}`;
  }

  get ownerURL(): string {
    return `https://github.com/${this.owner}`;
  }
}
