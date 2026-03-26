export async function uploadImageToCatbox(file: File): Promise<string | null> {
  try {
    const formData = new FormData();
    formData.append('reqtype', 'fileupload');
    formData.append('fileToUpload', file);

    const response = await fetch('https://catbox.moe/user/api.php', {
      method: 'POST',
      body: formData,
    });

    if (response.ok) {
      const url = await response.text();
      if (url.startsWith('https://')) {
        return url.trim();
      }
    }
    return null;
  } catch (error) {
    console.error('Catbox upload error:', error);
    return null;
  }
}
