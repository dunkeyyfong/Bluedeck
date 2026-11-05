#import "BDExports.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>

#ifndef LC_DYLD_EXPORTS_TRIE
#define LC_DYLD_EXPORTS_TRIE (0x33 | LC_REQ_DYLD)
#endif

static uint64_t BDReadUleb(const uint8_t **p, const uint8_t *end) {
	uint64_t result = 0;
	int shift = 0;
	while (*p < end) {
		uint8_t byte = *(*p)++;
		if (shift < 64) result |= (uint64_t)(byte & 0x7f) << shift;
		shift += 7;
		if (!(byte & 0x80)) break;
	}
	return result;
}

static void BDWalkTrie(const uint8_t *start, const uint8_t *end, const uint8_t *node, NSMutableString *name,
		NSString *prefix, NSMutableArray *out, int depth) {
	if (node >= end || depth > 128 || out.count > 20000) return;
	const uint8_t *p = node;
	uint64_t terminalSize = BDReadUleb(&p, end);
	if (terminalSize && [name hasPrefix:prefix]) [out addObject:[name copy]];
	p += terminalSize;
	if (p >= end) return;
	uint8_t children = *p++;
	for (uint8_t i = 0; i < children && p < end; i++) {
		const char *edge = (const char *)p;
		size_t len = strnlen(edge, (size_t)(end - p));
		p += len + 1;
		uint64_t offset = BDReadUleb(&p, end);
		NSString *edgeString = [[NSString alloc] initWithBytes:edge length:len encoding:NSUTF8StringEncoding] ?: @"?";
		// Prune branches that can no longer match the prefix.
		NSString *joined = [name stringByAppendingString:edgeString];
		NSUInteger common = MIN(joined.length, prefix.length);
		if (![[joined substringToIndex:common] isEqualToString:[prefix substringToIndex:common]]) continue;
		NSUInteger mark = name.length;
		[name appendString:edgeString];
		if (start + offset < end) BDWalkTrie(start, end, start + offset, name, prefix, out, depth + 1);
		[name deleteCharactersInRange:NSMakeRange(mark, name.length - mark)];
	}
}

NSArray<NSString *> *BDExportedSymbols(NSString *imageSuffix, NSString *prefix, NSString **error) {
	for (uint32_t i = 0; i < _dyld_image_count(); i++) {
		const char *path = _dyld_get_image_name(i);
		if (!path || ![@(path) hasSuffix:imageSuffix]) continue;

		const struct mach_header_64 *mh = (const struct mach_header_64 *)_dyld_get_image_header(i);
		intptr_t slide = _dyld_get_image_vmaddr_slide(i);
		const struct segment_command_64 *linkedit = NULL;
		uint32_t trieOff = 0, trieSize = 0;

		const uint8_t *cmd = (const uint8_t *)(mh + 1);
		for (uint32_t c = 0; c < mh->ncmds; c++) {
			const struct load_command *lc = (const struct load_command *)cmd;
			if (lc->cmd == LC_SEGMENT_64) {
				const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
				if (!strcmp(seg->segname, SEG_LINKEDIT)) linkedit = seg;
			} else if (lc->cmd == LC_DYLD_INFO || lc->cmd == LC_DYLD_INFO_ONLY) {
				const struct dyld_info_command *info = (const struct dyld_info_command *)lc;
				if (info->export_size) {
					trieOff = info->export_off;
					trieSize = info->export_size;
				}
			} else if (lc->cmd == LC_DYLD_EXPORTS_TRIE) {
				const struct linkedit_data_command *data = (const struct linkedit_data_command *)lc;
				trieOff = data->dataoff;
				trieSize = data->datasize;
			}
			cmd += lc->cmdsize;
		}
		if (!linkedit || !trieSize) {
			if (error) *error = @"không tìm thấy export trie";
			return nil;
		}
		const uint8_t *base = (const uint8_t *)(slide + linkedit->vmaddr - linkedit->fileoff);
		const uint8_t *start = base + trieOff;
		NSMutableArray *out = [NSMutableArray array];
		BDWalkTrie(start, start + trieSize, start, [NSMutableString string], prefix, out, 0);
		return [out sortedArrayUsingSelector:@selector(compare:)];
	}
	if (error) *error = [NSString stringWithFormat:@"chưa nạp %@", imageSuffix];
	return nil;
}
