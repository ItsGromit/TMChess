// ============================================================================
// SQUARE RACE MODE - THUMBNAIL RENDERING
// ============================================================================

namespace RaceMode {

namespace ThumbnailRendering {

// Dictionary to track downloads by URL (since we can't pass objects directly)
dictionary@ downloadingSquares = dictionary();

// Download queue for thumbnail URLs
array<string> downloadQueue;
bool downloaderRunning = false;

// Loading state tracking
bool isLoadingThumbnails = false;
int totalThumbnailsToLoad = 0;
int thumbnailsLoaded = 0;


/**
 * Queues a thumbnail for async loading (from cache or download)
 * This function is non-blocking and safe to call during rendering
 *
 * @param squareData Reference to the square's map data
 */
void DownloadThumbnail(SquareMapData@ squareData) {
    if (squareData is null) return;

    // Don't download if already loaded or loading
    if (squareData.thumbnailTexture !is null || squareData.thumbnailLoading) {
        return;
    }

    // Don't download if no URL
    if (squareData.thumbnailUrl.Length == 0) {
        return;
    }

    // Mark as loading immediately (non-blocking)
    squareData.thumbnailLoading = true;

    // Store reference in dictionary and add to queue for async processing
    downloadingSquares.Set(squareData.thumbnailUrl, @squareData);
    downloadQueue.InsertLast(squareData.thumbnailUrl);

    // Start the loader coroutine if not already running
    if (!downloaderRunning) {
        downloaderRunning = true;
        startnew(ThumbnailDownloaderCoroutine);
    }
}

/**
 * Async coroutine to process thumbnail download queue
 */
void ThumbnailDownloaderCoroutine() {
    while (downloadQueue.Length > 0) {
        string url = downloadQueue[0];
        downloadQueue.RemoveAt(0);

        // Retrieve the square data from the dictionary
        SquareMapData@ squareData;
        if (!downloadingSquares.Get(url, @squareData) || squareData is null) {
            continue;
        }

        DownloadSingleThumbnail(url, squareData);
        yield(); // Yield between downloads
    }
    downloaderRunning = false;
}

/**
 * After loading a thumbnail texture, propagate it to all other squares
 * that share the same TMX ID (map re-use). This ensures every square
 * with a re-used map displays the thumbnail.
 */
void PropagateTextureToMatchingSquares(SquareMapData@ source) {
    if (source is null || source.thumbnailTexture is null) return;

    int tmxId = source.tmxId;
    for (int r = 0; r < 8; r++) {
        if (uint(r) >= MapAssignment::boardMaps.Length) break;
        if (MapAssignment::boardMaps[r].Length == 0) continue;
        for (int c = 0; c < 8; c++) {
            if (uint(c) >= MapAssignment::boardMaps[r].Length) break;
            SquareMapData@ other = MapAssignment::boardMaps[r][c];
            if (other !is null && other !is source && other.tmxId == tmxId) {
                if (other.thumbnailTexture is null) {
                    @other.thumbnailTexture = source.thumbnailTexture;
                    other.thumbnailLoading = false;
                    other.thumbnailFailed = false;
                    thumbnailsLoaded++;
                    if (developerMode) print("[ThumbnailRendering] Shared thumbnail to square [" + r + "," + c + "] for " + other.mapName);
                    if (isLoadingThumbnails && thumbnailsLoaded >= totalThumbnailsToLoad) {
                        isLoadingThumbnails = false;
                        print("[ThumbnailRendering] All thumbnails loaded (" + thumbnailsLoaded + "/" + totalThumbnailsToLoad + ")");
                    }
                }
            }
        }
    }
}

/**
 * Loads or downloads a single thumbnail (called from the queue processor)
 * First tries to load from cache, then downloads if not cached
 */
void DownloadSingleThumbnail(const string &in url, SquareMapData@ squareData) {
    // First, check if thumbnail is already cached locally
    string filename = "thumb_" + squareData.tmxId + ".jpg";
    string cachePath = IO::FromStorageFolder("textures/thumbnails/" + filename);

    if (IO::FileExists(cachePath)) {
        try {
            IO::File file(cachePath, IO::FileMode::Read);
            if (file.Size() > 0) {
                auto buf = file.Read(file.Size());
                file.Close();
                @squareData.thumbnailTexture = UI::LoadTexture(buf);
                if (squareData.thumbnailTexture !is null) {
                    if (developerMode) print("[ThumbnailRendering] Loaded from cache: " + squareData.mapName);
                    squareData.thumbnailLoading = false;
                    squareData.thumbnailFailed = false;
                    thumbnailsLoaded++;
                    if (isLoadingThumbnails && thumbnailsLoaded >= totalThumbnailsToLoad) {
                        isLoadingThumbnails = false;
                        print("[ThumbnailRendering] All thumbnails loaded (" + thumbnailsLoaded + "/" + totalThumbnailsToLoad + ")");
                    }
                    PropagateTextureToMatchingSquares(squareData);
                    downloadingSquares.Delete(url);
                    return;
                }
            }
            file.Close();
        } catch {
            warn("[ThumbnailRendering] Failed to load cached thumbnail, will re-download: " + filename);
            try { IO::Delete(cachePath); } catch {}
        }
    }

    // Not in cache, download from server
    try {
        if (developerMode) print("[ThumbnailRendering] Downloading: " + squareData.mapName);

        // Download the image
        auto req = Net::HttpGet(url);

        // Wait for completion
        while (!req.Finished()) {
            yield();
        }

        // Check for errors
        if (req.ResponseCode() != 200) {
            warn("[ThumbnailRendering] Failed to download thumbnail: HTTP " + req.ResponseCode());
            squareData.thumbnailLoading = false;
            squareData.thumbnailFailed = true;
            squareData.thumbnailRetryCount++;
            thumbnailsLoaded++;
            if (isLoadingThumbnails && thumbnailsLoaded >= totalThumbnailsToLoad) {
                isLoadingThumbnails = false;
            }
            downloadingSquares.Delete(url);
            return;
        }

        // Get image data as buffer
        MemoryBuffer@ imageData = req.Buffer();

        if (imageData.GetSize() == 0) {
            warn("[ThumbnailRendering] Empty response for thumbnail: " + squareData.mapName);
            squareData.thumbnailLoading = false;
            squareData.thumbnailFailed = true;
            squareData.thumbnailRetryCount++;
            thumbnailsLoaded++;
            if (isLoadingThumbnails && thumbnailsLoaded >= totalThumbnailsToLoad) {
                isLoadingThumbnails = false;
            }
            downloadingSquares.Delete(url);
            return;
        }

        // Cache the downloaded file
        IO::CreateFolder(IO::FromStorageFolder("textures/thumbnails"), true);

        try {
            IO::File file(cachePath, IO::FileMode::Write);
            file.Write(imageData);
            file.Close();
            if (developerMode) print("[ThumbnailRendering] Cached: " + filename);
        } catch {
            warn("[ThumbnailRendering] Failed to cache thumbnail: " + filename);
        }

        // Load texture from memory buffer
        @squareData.thumbnailTexture = UI::LoadTexture(imageData);

        if (squareData.thumbnailTexture !is null) {
            if (developerMode) print("[ThumbnailRendering] Loaded: " + squareData.mapName);
            squareData.thumbnailFailed = false;
            squareData.thumbnailRetryCount = 0;
            PropagateTextureToMatchingSquares(squareData);
        } else {
            warn("[ThumbnailRendering] Failed to create texture for " + squareData.mapName);
            squareData.thumbnailFailed = true;
            squareData.thumbnailRetryCount++;
        }

    } catch {
        warn("[ThumbnailRendering] Exception downloading thumbnail: " + getExceptionInfo());
        squareData.thumbnailFailed = true;
        squareData.thumbnailRetryCount++;
    }

    squareData.thumbnailLoading = false;
    thumbnailsLoaded++;

    if (isLoadingThumbnails && thumbnailsLoaded >= totalThumbnailsToLoad) {
        isLoadingThumbnails = false;
        print("[ThumbnailRendering] All thumbnails loaded (" + thumbnailsLoaded + "/" + totalThumbnailsToLoad + ")");
    }

    downloadingSquares.Delete(url);
}

/**
 * Renders a map thumbnail on a chess board square
 * This should be called after the square button is drawn, as it uses GetItemRect()
 *
 * @param row The row index (0-7)
 * @param col The column index (0-7)
 */
void RenderMapThumbnail(int row, int col) {
    // Get the square's map data
    if (row < 0 || row >= 8 || col < 0 || col >= 8) return;

    // Check if boardMaps is initialized
    if (MapAssignment::boardMaps.Length <= uint(row)) return;
    if (MapAssignment::boardMaps[row].Length <= uint(col)) return;

    SquareMapData@ squareData = MapAssignment::boardMaps[row][col];
    if (squareData is null) return;

    // Only render thumbnail if this map was assigned by the server
    // (tmxId > 0 means server sent map data, -1 means no map assigned)
    if (squareData.tmxId <= 0) return;

    // If thumbnail not loaded, try to download it
    if (squareData.thumbnailTexture is null && !squareData.thumbnailLoading) {
        // Check if this thumbnail has failed and should retry
        const int MAX_RETRY_COUNT = 3;
        if (squareData.thumbnailFailed && squareData.thumbnailRetryCount < MAX_RETRY_COUNT) {
            if (developerMode) print("[ThumbnailRendering] Retrying failed thumbnail for " + squareData.mapName + " (attempt " + (squareData.thumbnailRetryCount + 1) + "/" + MAX_RETRY_COUNT + ")");
            squareData.thumbnailFailed = false; // Reset flag for retry
            DownloadThumbnail(squareData);
        } else if (!squareData.thumbnailFailed) {
            // First download attempt
            DownloadThumbnail(squareData);
        } else {
            // Exceeded max retries, log and skip
            if (squareData.thumbnailRetryCount >= MAX_RETRY_COUNT) {
                // Only log once when we first hit the limit
                if (squareData.thumbnailRetryCount == MAX_RETRY_COUNT) {
                    warn("[ThumbnailRendering] Max retries reached for " + squareData.mapName + ", giving up");
                    squareData.thumbnailRetryCount++; // Increment to prevent repeated logging
                }
            }
        }
        return; // Don't render until loaded
    }

    // If still loading or no texture, don't render
    if (squareData.thumbnailTexture is null) return;

    // Get the screen position and size of the last drawn item (the button)
    vec4 rect = UI::GetItemRect();
    vec2 pos = vec2(rect.x, rect.y);
    vec2 size = vec2(rect.z, rect.w);

    auto drawList = UI::GetWindowDrawList();

    float padding = 8.0f;
    vec2 imagePos = pos + vec2(padding, padding);
    vec2 imageSize = (size - vec2(padding * 2, padding * 2)) * ThumbnailSize;
    vec4 thumbnailColor;
    drawList.AddImage(squareData.thumbnailTexture, imagePos, imageSize, 0xFFFFFF80);
}

// TMX tag definitions: maps tag ID -> {name, color}
// Used by MapAssignment to resolve tag IDs from the server to display names/colors
dictionary tagDefinitions;
bool tagDefinitionsLoaded = false;


// Loads hardcoded TMX tag definitions (ID -> Name, Color mapping)
// Called by MapAssignment when applying server board maps
void LoadHardcodedTagDefinitions() {
    if (tagDefinitionsLoaded) return;

    // TMX tag definitions: Set("id", "name|hexcolor")
    tagDefinitions.Set("1",  "Race|808080");
    tagDefinitions.Set("2",  "FullSpeed|4aa341");
    tagDefinitions.Set("3",  "Tech|2d85d0");
    tagDefinitions.Set("4",  "RPG|7e0e87");
    tagDefinitions.Set("5",  "LOL|d31d72");
    tagDefinitions.Set("6",  "Press Forward|33b0a2");
    tagDefinitions.Set("7",  "SpeedTech|21b526");
    tagDefinitions.Set("8",  "MultiLap|b14bb5");
    tagDefinitions.Set("9",  "Offroad|7c5b29");
    tagDefinitions.Set("10", "Trial|6c6f72");
    tagDefinitions.Set("11", "ZRT|3e8a8e");
    tagDefinitions.Set("12", "SpeedFun|808080");
    tagDefinitions.Set("13", "Competitive|3d56a8");
    tagDefinitions.Set("14", "Ice|69dbff");
    tagDefinitions.Set("15", "Dirt|9c6644");
    tagDefinitions.Set("16", "Stunt|808080");
    tagDefinitions.Set("17", "Reactor|d04040");
    tagDefinitions.Set("18", "Platform|2e6b9e");
    tagDefinitions.Set("19", "Slow Motion|d0a03d");
    tagDefinitions.Set("20", "Bumper|d0672e");
    tagDefinitions.Set("21", "Fragile|c94e4e");
    tagDefinitions.Set("22", "Scenery|508228");
    tagDefinitions.Set("23", "Kacky|e6345a");
    tagDefinitions.Set("24", "Endurance|5b6e82");
    tagDefinitions.Set("25", "Mini|808080");
    tagDefinitions.Set("26", "Remake|808080");
    tagDefinitions.Set("27", "Mixed|808080");
    tagDefinitions.Set("28", "Nascar|808080");
    tagDefinitions.Set("29", "SpeedDrift|808080");
    tagDefinitions.Set("30", "Minigame|808080");
    tagDefinitions.Set("31", "Obstacle|808080");
    tagDefinitions.Set("32", "Transitional|808080");
    tagDefinitions.Set("33", "Grass|4ca64c");
    tagDefinitions.Set("34", "Backwards|808080");
    tagDefinitions.Set("35", "Freewheel|808080");
    tagDefinitions.Set("36", "Signature|f1c438");
    tagDefinitions.Set("37", "Royal|ff9800");
    tagDefinitions.Set("38", "Water|69dbff");
    tagDefinitions.Set("39", "Plastic|ffd200");
    tagDefinitions.Set("40", "Arena|808080");
    tagDefinitions.Set("41", "Bobsleigh|3b7db5");
    tagDefinitions.Set("42", "Pathfinding|808080");
    tagDefinitions.Set("43", "Sausage|808080");
    tagDefinitions.Set("44", "Educational|808080");

    tagDefinitionsLoaded = true;
}

/**
 * Looks up a tag by its numeric ID and returns a MapTag
 * Returns null if the tag ID is not found
 */
MapTag@ LookupTag(int tagId) {
    string key = "" + tagId;
    string val;
    if (tagDefinitions.Get(key, val)) {
        int sep = val.IndexOf("|");
        if (sep >= 0) {
            string name = val.SubStr(0, sep);
            string color = val.SubStr(sep + 1);
            return MapTag(name, color);
        }
    }
    return null;
}

/**
 * Preloads thumbnails for all assigned maps
 */
void PreloadAllThumbnails() {
    if (developerMode) print("[ThumbnailRendering] Preloading all thumbnails...");

    // Set loading state immediately to show loading screen
    isLoadingThumbnails = true;

    // Reset counters
    thumbnailsLoaded = 0;
    totalThumbnailsToLoad = 0;

    // Count thumbnails that need to be downloaded
    for (int row = 0; row < 8; row++) {
        // Check if row exists
        if (uint(row) >= MapAssignment::boardMaps.Length) break;
        if (MapAssignment::boardMaps[row].Length == 0) continue;

        for (int col = 0; col < 8; col++) {
            // Check if column exists
            if (uint(col) >= MapAssignment::boardMaps[row].Length) break;

            SquareMapData@ squareData = MapAssignment::boardMaps[row][col];
            if (squareData !is null && squareData.tmxId > 0) {
                // Only count if not already loaded
                if (squareData.thumbnailTexture is null && !squareData.thumbnailLoading) {
                    totalThumbnailsToLoad++;
                }
            }
        }
    }

    // If no thumbnails to load, immediately disable loading state
    if (totalThumbnailsToLoad == 0) {
        if (developerMode) print("[ThumbnailRendering] All thumbnails already cached");
        isLoadingThumbnails = false;
        return;
    }

    if (developerMode) print("[ThumbnailRendering] Need to download " + totalThumbnailsToLoad + " thumbnails");

    // Start downloading
    for (int row = 0; row < 8; row++) {
        // Check if row exists
        if (uint(row) >= MapAssignment::boardMaps.Length) break;
        if (MapAssignment::boardMaps[row].Length == 0) continue;

        for (int col = 0; col < 8; col++) {
            // Check if column exists
            if (uint(col) >= MapAssignment::boardMaps[row].Length) break;

            SquareMapData@ squareData = MapAssignment::boardMaps[row][col];
            if (squareData !is null && squareData.tmxId > 0) {
                DownloadThumbnail(squareData);
            }
        }
    }

    if (developerMode) print("[ThumbnailRendering] Started downloading " + totalThumbnailsToLoad + " thumbnails");
}

/**
 * Returns whether any assets are currently being loaded (thumbnails, pieces, or logo)
 */
bool IsLoadingThumbnails() {
    return isLoadingThumbnails || gPieces.isLoading || isLoadingLogo;
}

/**
 * Returns the loading progress (0.0 to 1.0)
 */
float GetLoadingProgress() {
    // Calculate total items to load (thumbnails + pieces + logo)
    int totalItems = totalThumbnailsToLoad + gPieces.totalPieces + 1;
    if (totalItems == 0) return 1.0f;

    // Calculate loaded items
    int loadedItems = thumbnailsLoaded;
    if (!gPieces.isLoading) loadedItems += gPieces.totalPieces;
    else loadedItems += gPieces.piecesLoaded;
    if (!isLoadingLogo) loadedItems += 1;

    return float(loadedItems) / float(totalItems);
}

/**
 * Returns formatted loading text
 */
string GetLoadingText() {
    // Check what's currently loading
    if (isLoadingLogo) {
        return "Loading logo...";
    } else if (gPieces.isLoading) {
        return "Loading piece assets... " + gPieces.piecesLoaded + "/" + gPieces.totalPieces;
    } else if (isLoadingThumbnails) {
        return "Loading thumbnails... " + thumbnailsLoaded + "/" + totalThumbnailsToLoad;
    }
    return "Ready";
}

/**
 * Clears all cached thumbnails to free memory and delete cached files
 */
void ClearThumbnailCache() {
    if (developerMode) print("[ThumbnailRendering] Clearing thumbnail cache...");

    int clearedMemoryCount = 0;
    int deletedFileCount = 0;

    // Clear memory references
    if (MapAssignment::boardMaps.Length > 0) {
        for (int row = 0; row < 8; row++) {
            // Check if row is initialized
            if (row >= int(MapAssignment::boardMaps.Length)) break;
            if (MapAssignment::boardMaps[row].Length == 0) continue;

            for (int col = 0; col < 8; col++) {
                // Check if column is initialized
                if (col >= int(MapAssignment::boardMaps[row].Length)) break;

                SquareMapData@ squareData = MapAssignment::boardMaps[row][col];
                if (squareData !is null) {
                    @squareData.thumbnailTexture = null;
                    squareData.thumbnailLoading = false;
                    squareData.thumbnailFailed = false;
                    squareData.thumbnailRetryCount = 0;
                    clearedMemoryCount++;
                }
            }
        }
    }

    // Delete cached files from disk
    string thumbnailsFolder = IO::FromStorageFolder("textures/thumbnails");
    if (IO::FolderExists(thumbnailsFolder)) {
        array<string> files = IO::IndexFolder(thumbnailsFolder, false);
        for (uint i = 0; i < files.Length; i++) {
            // Only delete .jpg files
            if (files[i].EndsWith(".jpg")) {
                string filePath = thumbnailsFolder + "/" + files[i];
                if (IO::FileExists(filePath)) {
                    IO::Delete(filePath);
                    deletedFileCount++;
                }
            }
        }
    }

    if (developerMode) print("[ThumbnailRendering] Cleared " + clearedMemoryCount + " thumbnails from memory, deleted " + deletedFileCount + " cached files");
}

}

}
