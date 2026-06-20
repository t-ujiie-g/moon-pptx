// pptx-validate — run the Open XML SDK validator over one or more .pptx
// files and fail (non-zero exit) if any non-baselined error is found.
//
// Why this exists
// ---------------
// moon-pptx generates .pptx bytes in pure MoonBit with no access to a real
// PowerPoint. Historically, "does PowerPoint show a repair prompt?" was only
// ever answered by a human opening the deck (several bugs in the changelog —
// define_master id collisions, foreign-namespace prefix scoping, invalid
// chart dLblPos — were caught exactly that way, late). Microsoft's
// OpenXmlValidator runs the same family of schema + semantic checks that
// PowerPoint runs on open, so a clean run here catches that whole class of
// "repair" triggers automatically, in CI, on every PR.
//
// Usage
// -----
//   dotnet run --project tools/pptx-validate -- <path...> [--baseline FILE] [--version V]
//
//   <path...>      one or more .pptx files, or directories searched recursively
//   --baseline F   a text file of substrings; any validation error whose
//                  description contains one is ignored (documented quirks /
//                  false positives only — keep it short and commented)
//   --version V    target FileFormatVersions (default Office2021)
//
// Exit codes: 0 = all clean · 1 = validation errors · 2 = bad invocation.

using DocumentFormat.OpenXml; // FileFormatVersions
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Validation;

var paths = new List<string>();
string? baselinePath = null;
var version = FileFormatVersions.Office2021;

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--baseline":
            if (++i >= args.Length) { Console.Error.WriteLine("--baseline needs a path"); return 2; }
            baselinePath = args[i];
            break;
        case "--version":
            if (++i >= args.Length || !Enum.TryParse(args[i], out version))
            {
                Console.Error.WriteLine($"--version needs one of: {string.Join(", ", Enum.GetNames<FileFormatVersions>())}");
                return 2;
            }
            break;
        default:
            paths.Add(args[i]);
            break;
    }
}

// Expand directories into the .pptx files they contain.
var files = new List<string>();
foreach (var p in paths)
{
    if (Directory.Exists(p))
        files.AddRange(Directory.GetFiles(p, "*.pptx", SearchOption.AllDirectories));
    else if (File.Exists(p))
        files.Add(p);
    else
    {
        Console.Error.WriteLine($"path not found: {p}");
        return 2;
    }
}

if (files.Count == 0)
{
    Console.Error.WriteLine("no .pptx files to validate (pass files or directories)");
    return 2;
}

// Baseline: non-empty, non-comment lines are substrings to ignore.
var baseline = baselinePath is not null && File.Exists(baselinePath)
    ? File.ReadAllLines(baselinePath)
        .Select(l => l.Trim())
        .Where(l => l.Length > 0 && !l.StartsWith('#'))
        .ToList()
    : new List<string>();

var validator = new OpenXmlValidator(version);
int filesFailed = 0, totalErrors = 0, totalIgnored = 0;

foreach (var file in files.OrderBy(f => f, StringComparer.Ordinal))
{
    // Flatten each error into plain strings *while the package is open* —
    // ValidationErrorInfo.Part is a live part whose .Uri throws once the
    // PresentationDocument is disposed.
    var rows = new List<(string Id, string Type, string Desc, string Part, string Path)>();
    try
    {
        using var doc = PresentationDocument.Open(file, false);
        foreach (var e in validator.Validate(doc))
        {
            rows.Add((
                e.Id ?? string.Empty,
                e.ErrorType.ToString(),
                e.Description ?? string.Empty,
                e.Part?.Uri?.ToString() ?? string.Empty,
                e.Path?.XPath ?? string.Empty));
        }
    }
    catch (Exception ex)
    {
        // Failing to even open the package is the strongest "PowerPoint would
        // repair this" signal there is.
        filesFailed++;
        Console.WriteLine($"OPEN-FAIL  {Path.GetFileName(file)}");
        Console.WriteLine($"    {ex.GetType().Name}: {ex.Message}");
        continue;
    }

    var real = rows
        .Where(r => !baseline.Any(b => r.Desc.Contains(b)))
        .ToList();
    totalIgnored += rows.Count - real.Count;

    if (real.Count == 0)
    {
        var ignoredNote = rows.Count > 0 ? $"  ({rows.Count} baselined)" : string.Empty;
        Console.WriteLine($"OK         {Path.GetFileName(file)}{ignoredNote}");
        continue;
    }

    filesFailed++;
    totalErrors += real.Count;
    Console.WriteLine($"FAIL       {Path.GetFileName(file)}  ({real.Count} error(s))");
    foreach (var r in real)
    {
        Console.WriteLine($"    [{r.Type}/{r.Id}] {r.Desc}");
        if (r.Part.Length > 0) Console.WriteLine($"        part: {r.Part}");
        if (r.Path.Length > 0) Console.WriteLine($"        path: {r.Path}");
    }
}

Console.WriteLine();
Console.WriteLine($"{files.Count} file(s) · {filesFailed} failed · {totalErrors} error(s) · {totalIgnored} baselined · target {version}");
return filesFailed == 0 ? 0 : 1;
