/**
 * This service performs queries at the REST endpoint of the content type cache.
 */
export default class ContentTypeCacheService {
    constructor(
        private baseUrl: string,
        private csrfToken?: string
    ) {}

    /**
     * Gets the last update date and time.
     */
    public async getCacheUpdate(): Promise<Date | null> {
        const response = await fetch(`${this.baseUrl}/update`, {
            credentials: 'include'
        });
        if (response.ok) {
            const { lastUpdate } = await response.json();
            return lastUpdate === null ? null : new Date(lastUpdate);
        }
        throw new Error(
            `Could not get content type cache update date: ${response.status} - ${response.statusText}`
        );
    }

    /**
     * Triggers a content type cache update that will contact the H5P Hub and
     * retrieve the latest content type list.
     */
    public async postUpdateCache(): Promise<Date> {
        const headers: HeadersInit = {
            'Content-Type': 'application/json'
        };
        if (this.csrfToken) {
            headers['CSRF-Token'] = this.csrfToken;
        }
        const response = await fetch(`${this.baseUrl}/update`, {
            method: 'POST',
            credentials: 'include',
            headers
        });
        if (response.ok) {
            return new Date((await response.json()).lastUpdate);
        }
        throw new Error(
            `Could not update content type cache: ${response.status} - ${response.statusText}`
        );
    }

    public setCsrfToken(csrfToken: string | undefined): void {
        this.csrfToken = csrfToken;
    }
}
