Here's a more comprehensive guide to the ScreenScraper API, detailing all available endpoints based on the provided document.

### \#\# 🔑 Core Concepts & Common Parameters

[cite\_start]Almost every API call is a `GET` request [cite: 64] that shares a set of common parameters for authentication and configuration. [cite\_start]The API can return data in **XML** (default) or **JSON** format[cite: 58].

  * **Developer Credentials (Required)**

      * [cite\_start]`devid`: Your developer identifier[cite: 66, 123, 140].
      * [cite\_start]`devpassword`: Your developer password[cite: 66, 124, 141].
      * [cite\_start]`softname`: The name of your application making the call[cite: 66, 125, 142].

  * **User Credentials (Optional but Recommended)**

      * [cite\_start]`ssid`: The ScreenScraper username of the end-user[cite: 66, 144].
      * [cite\_start]`sspassword`: The ScreenScraper password of the end-user[cite: 66, 145]. Providing these gives the user access to their specific thread and quota limits.

  * **Output Format**

      * `output`: Specifies the format of the returned data. [cite\_start]Can be `xml` (the default) or `json`[cite: 66, 126, 143].

-----

### \#\# ⚙️ Infrastructure & User Endpoints

These endpoints provide information about the API's server status and details about a specific user's account.

#### **`ssinfralnfos.php`**

[cite\_start]Provides information about the ScreenScraper infrastructure[cite: 95].

  * **Input Parameters**

      * [cite\_start]Requires the standard developer credentials and `output` parameter[cite: 123, 124, 125, 126].

  * **Returned Elements**

      * [cite\_start]`cpul`, `cpu2`, `cpu3`: CPU usage percentage for each of the three servers[cite: 129].
      * [cite\_start]`threadsmin`: The number of API accesses in the last minute[cite: 129].
      * [cite\_start]`nbscrapeurs`: The number of scrapers using the API in the last minute[cite: 130].
      * [cite\_start]`apiacces`: Total number of API accesses for the current day[cite: 130].
      * [cite\_start]`closefornomember`: A flag indicating if the API is closed for non-registered users (0=open, 1=closed)[cite: 132].
      * [cite\_start]`closeforleecher`: A flag indicating if the API is closed for non-contributing members (0=open, 1=closed)[cite: 132].
      * [cite\_start]`maxthreadfornonmember` / `threadfornonmember`: The maximum and current number of threads open for non-members[cite: 134].
      * [cite\_start]`maxthreadformember` / `threadformember`: The maximum and current number of threads open for members[cite: 135, 136].

  * **Example Call**

    ```
    [cite_start]https://api.screenscraper.fr/api2/ssinfralnfos.php?devid=xxx&devpassword=yyy&softname=zzz&output=xml [cite: 137]
    ```

#### **`ssuserInfos.php`**

[cite\_start]Provides detailed information about a ScreenScraper user's account and quotas[cite: 96, 138].

  * **Input Parameters**

      * [cite\_start]Requires developer and user credentials, plus the `output` parameter[cite: 140, 141, 142, 143, 144, 145].

  * **Returned Elements**

      * [cite\_start]`id`: The user's pseudo/username[cite: 151].
      * [cite\_start]`niveau`: The user's level on ScreenScraper[cite: 154].
      * [cite\_start]`contribution`: The user's financial contribution level[cite: 155].
      * [cite\_start]`uploadsysteme`, `uploadinfos`, `romasso`, `uploadmedia`: Counters for the user's validated contributions[cite: 155, 156, 157].
      * [cite\_start]`maxthreads`: The total number of simultaneous threads the user is allowed[cite: 159].
      * [cite\_start]`maxdownloadspeed`: The user's maximum allowed download speed in Ko/s[cite: 159].
      * [cite\_start]`requeststoday`: Total API requests made by the user today[cite: 161].
      * [cite\_start]`requestskotoday`: Total API requests by the user today that resulted in a "not found" error[cite: 162].
      * [cite\_start]`maxrequestspermin`: The user's maximum allowed requests per minute[cite: 163].
      * [cite\_start]`maxrequestsperday`: The user's maximum allowed requests per day[cite: 164].
      * [cite\_start]`maxrequestskoperday`: The user's maximum allowed "not found" requests per day[cite: 165].

  * **Example Call**

    ```
    [cite_start]https://api.screenscraper.fr/api2/ssuserInfos.php?devid=xxx&devpassword=yyy&softname=zzz&output=xml&ssid=afonsosousah&sspassword=123afonso [cite: 170]
    ```

-----

### \#\# 📚 Data List Endpoints

These endpoints are used to retrieve lists of standardized data, such as all available systems, genres, or regions. They are essential for understanding the IDs and values returned by other endpoints.

| Endpoint | Description |
| :--- | :--- |
| **`systemesliste.php`** | [cite\_start]Lists all game systems, including their IDs, names for various front-ends (Recalbox, Retropie, etc.), and extensive media URLs for logos, photos, bezels, and more [cite: 111, 501-586]. |
| **`genresListe.php`** | [cite\_start]Lists all game genres with their IDs and names in multiple languages (French, English, German, etc.) [cite: 101, 239-244]. |
| **`regionsListe.php`** | [cite\_start]Lists all geographical regions with their IDs and names in multiple languages[cite: 102, 263]. |
| **`languesliste.php`** | [cite\_start]Lists all languages with their IDs and names in multiple languages [cite: 103, 286-287]. |
| **`classificationListe.php`** | [cite\_start]Lists game rating systems (like PEGI, ESRB) with their IDs and names [cite: 104, 306-308]. |
| **`nbJoueursListe.php`** | [cite\_start]Lists the possible number of players (e.g., "1-2", "4 simultaneous") with their IDs[cite: 98, 196, 197]. |
| **`romTypesListe.php`** | [cite\_start]Lists the types of ROMs available (e.g., "rom", "iso", "dossier")[cite: 100, 225]. |
| **`supportTypesListe.php`** | [cite\_start]Lists the original media types for games (e.g., "Cartridge", "CD-ROM")[cite: 99, 214]. |
| **`mediasSystemeListe.php`** | [cite\_start]Lists all available *types* of media for systems (e.g., logo, controller image) [cite: 105, 329-341]. |
| **`mediasJeuListe.php`** | [cite\_start]Lists all available *types* of media for games (e.g., screenshot, box2d) [cite: 106, 356-368]. |
| **`infosJeuListe.php`** | [cite\_start]Lists all available *types* of text-based info for games [cite: 107, 383-393]. |
| **`infosRomListe.php`** | [cite\_start]Lists all available *types* of text-based info for ROMs [cite: 108, 411-421]. |
| **`userlevelsListe.php`** | [cite\_start]Lists all user levels on ScreenScraper[cite: 97, 182, 183]. |

-----

### \#\# 🕹️ Game Scraping Endpoints

These are the primary endpoints used to find game data and media.

#### **`jeuRecherche.php`**

[cite\_start]Searches for a game by its name[cite: 114]. [cite\_start]It returns a list of up to 30 games, ranked by probability[cite: 114].

  * **Input Parameters**
      * [cite\_start]Standard developer/user credentials and `output` parameter[cite: 631, 632, 633, 634, 635, 636].
      * [cite\_start]`systemeid` (optional): The numeric ID of the system to narrow the search[cite: 637].
      * [cite\_start]`recherche`: The name of the game you are searching for[cite: 638].

#### **`jeuInfos.php`**

[cite\_start]Retrieves all information and media for a specific game[cite: 115]. This is the most powerful endpoint for scraping. You can identify a game using its ID, ROM filename, or checksums.

  * **Input Parameters (one or more of the following to identify the game)**
      * [cite\_start]`crc`, `md5`, `sha1`: Checksum of the ROM file[cite: 66].
      * [cite\_start]`romnom`: The filename of the ROM[cite: 66].
      * [cite\_start]`romtype`: The type of the ROM (e.g., "rom")[cite: 66].
      * [cite\_start]`systemeid`: The numeric ID of the system the game belongs to[cite: 66].

-----

### \#\# 🖼️ Media Download Endpoints

These endpoints deliver the actual image or video files. For optimization, you can provide a `crc`, `md5`, or `sha1` checksum of a local file. [cite\_start]If it matches the server's file, the API will return a simple text confirmation (`CRCOK`, `MD5OK`, etc.) instead of re-downloading the data[cite: 442, 464, 596, 597, 598, 607]. [cite\_start]If no media is found, it returns `NOMEDIA`[cite: 443, 466, 608].

| Endpoint | Description | Key Parameters |
| :--- | :--- | :--- |
| **`mediaSysteme.php`** | [cite\_start]Downloads image media for a system (e.g., a console photo)[cite: 112, 589]. | [cite\_start]`systemeid`, `media` (the media type identifier from `systemesListe.php`)[cite: 599, 600]. |
| **`mediaVideoSysteme.php`** | [cite\_start]Downloads video media for a system[cite: 113, 611]. | [cite\_start]`systemeid`, `media`[cite: 621, 622]. |
| **`mediaJeu.php`** | [cite\_start]Downloads image media for a game (e.g., box art)[cite: 116]. | Game identifiers (ID, CRC, etc.), `media` (the media type, e.g., "box-2D-wor"). |
| **`mediaVideoJeu.php`** | [cite\_start]Downloads video media for a game[cite: 117]. | Game identifiers, `media`. |
| **`mediaManuelJeu.php`** | [cite\_start]Downloads the manual for a game[cite: 118]. | Game identifiers. |
| **`mediaGroup.php`** | [cite\_start]Downloads images for game groups (like genres)[cite: 109, 424]. | [cite\_start]`groupid`, `media` (e.g., "logo-monochrome")[cite: 434, 435]. |
| **`mediaCompagnie.php`** | [cite\_start]Downloads images for companies (developers/publishers)[cite: 110, 446]. | [cite\_start]`companyid`, `media` (e.g., "logo-monochrome")[cite: 456, 457]. |

-----

### \#\# 📤 Contribution Endpoints

These endpoints are for advanced users to automate contributions to the ScreenScraper database.

  * [cite\_start]**`botNote.php`**: Automates sending game ratings from a ScreenScraper member[cite: 119].
  * [cite\_start]**`botProposition.php`**: Automates the submission of new game info or media to ScreenScraper[cite: 120].

-----

### \#\# ⚠️ Error Codes

[cite\_start]The API uses standard HTTP status codes to report errors[cite: 87].

| Code | Description |
| :--- | :--- |
| **400** | [cite\_start]Bad Request: Your URL is missing required fields or a parameter (like a CRC or filename) is malformed[cite: 88]. |
| **403** | [cite\_start]Forbidden: Your developer credentials are incorrect[cite: 93]. |
| **404** | [cite\_start]Not Found: The requested game or ROM could not be found in the database[cite: 93]. |
| **423** | [cite\_start]Locked: The API is completely closed due to severe server issues[cite: 93]. |
| **429** | [cite\_start]Too Many Requests: You have exceeded your thread or per-minute request limit[cite: 93]. |
| **430** | [cite\_start]Request Header Fields Too Large: You have exceeded your total daily scraping quota[cite: 93]. |
| **431** | [cite\_start]Unavailable For Legal Reasons: You have exceeded your daily quota for ROMs not found in the database[cite: 93]. |