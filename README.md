# Filen Mac OS File Provider

Integrate Filen with the Mac Finder app.

## Known Limitations

- .playground, folders that imitate files, and certain types of hidden files are confusing type identifiers and are handled as a special case, however it is not reliable. I **strongly** warn against using FilenMacFileProvider as a directory to work in for coding projects. To backup coding projects, please compress the folder before transferring into the file provider.

- Upload speed is limited around 15 MB/s (not a software cap) due to encryption speeds of the files. This is a tradeoff made for better security.
