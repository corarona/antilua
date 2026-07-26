#include "guiEditBoxWithSyntaxHighlight.h"
#include "guiFormSpecMenu.h"
#include "IGUISkin.h"
#include "IGUIEnvironment.h"
#include "IGUIFont.h"
#include "IGUIScrollBar.h"
#include "IVideoDriver.h"
#include "util/string.h"
#include "client/fontengine.h"
#include "client/keycode.h"
#include <cwctype>
#include <chrono>
#include <cwchar>

// ---- Static keyword/builtin tables ----

const std::unordered_set<std::wstring> GUIEditBoxWithSyntaxHighlight::s_keywords = {
	L"and", L"break", L"do", L"else", L"elseif", L"end",
	L"for", L"function", L"if", L"in", L"local", L"nil",
	L"not", L"or", L"repeat", L"return", L"then", L"true",
	L"until", L"while", L"false",
};

const std::unordered_set<std::wstring> GUIEditBoxWithSyntaxHighlight::s_builtins = {
	L"print", L"pcall", L"loadstring", L"load", L"dofile",
	L"loadfile", L"require", L"module", L"type", L"pairs",
	L"ipairs", L"next", L"tostring", L"tonumber", L"unpack",
	L"select", L"setmetatable", L"getmetatable", L"rawget",
	L"rawset", L"rawequal", L"error", L"assert", L"collectgarbage",
	L"xpcall", L"self",
};

// ---- SyntaxHighlightColors ----

SyntaxHighlightColors SyntaxHighlightColors::fromOptionString(const std::string &opts)
{
	SyntaxHighlightColors c;
	if (opts.empty())
		return c;

	std::vector<std::string> pairs = split(opts, ',');
	for (auto &pair : pairs) {
		size_t eq = pair.find('=');
		if (eq == std::string::npos)
			continue;
		std::string key = trim(pair.substr(0, eq));
		std::string val = trim(pair.substr(eq + 1));
		video::SColor color;
		if (!parseColorString(val, color, true))
			continue;

		if (key == "keyword")
			c.keyword = color;
		else if (key == "string")
			c.string = color;
		else if (key == "comment")
			c.comment = color;
		else if (key == "number")
			c.number = color;
		else if (key == "builtin")
			c.builtin = color;
		else if (key == "identifier")
			c.identifier = color;
		else if (key == "operator")
			c.op = color;
		else if (key == "punctuation")
			c.punct = color;
		else if (key == "text")
			c.text = color;
	}
	return c;
}

static u32 get_time_ms()
{
	return std::chrono::duration_cast<std::chrono::milliseconds>(
		std::chrono::steady_clock::now().time_since_epoch()).count();
}

// ---- GUIEditBoxWithSyntaxHighlight ----

GUIEditBoxWithSyntaxHighlight::GUIEditBoxWithSyntaxHighlight(const wchar_t *text,
		bool border, gui::IGUIEnvironment *environment, IGUIElement *parent,
		s32 id, const core::rect<s32> &rectangle, ISimpleTextureSource *tsrc,
		bool writable, const SyntaxHighlightColors &colors) :
	GUIEditBoxWithScrollBar(text, border, environment, parent, id, rectangle,
		tsrc, writable, true),
	m_colors(colors)
{
	setWordWrap(false);
}

void GUIEditBoxWithSyntaxHighlight::setText(const wchar_t *text)
{
	gui::CGUIEditBox::setText(text);
	m_tokenized_text_size = 0; // force re-tokenize
}

video::SColor GUIEditBoxWithSyntaxHighlight::colorForToken(TokenType type) const
{
	switch (type) {
	case T_KEYWORD:       return m_colors.keyword;
	case T_STRING:        return m_colors.string;
	case T_COMMENT:       return m_colors.comment;
	case T_NUMBER:        return m_colors.number;
	case T_BUILTIN:       return m_colors.builtin;
	case T_IDENTIFIER:    return m_colors.identifier;
	case T_OPERATOR:      return m_colors.op;
	case T_PUNCTUATION:   return m_colors.punct;
	default:              return m_colors.text;
	}
}

GUIEditBoxWithSyntaxHighlight::TokenType
GUIEditBoxWithSyntaxHighlight::classifyWord(const std::wstring &word) const
{
	if (s_keywords.find(word) != s_keywords.end())
		return T_KEYWORD;
	if (s_builtins.find(word) != s_builtins.end())
		return T_BUILTIN;
	return T_IDENTIFIER;
}

void GUIEditBoxWithSyntaxHighlight::tokenizeAll()
{
	m_line_tokens.clear();

	bool in_block_comment = false;
	bool in_long_string = false;
	size_t line_start = 0;

	for (size_t i = 0; i <= Text.size(); i++) {
		if (i == Text.size() || Text[i] == L'\n') {
			core::stringw line = Text.subString(line_start, i - line_start);
			std::vector<Token> tokens;

			size_t pos = 0;
			while (pos < line.size()) {
				wchar_t c = line[pos];

				// Block comment continuation
				if (in_block_comment) {
					if (c == L']' && pos + 1 < line.size() && line[pos + 1] == L']') {
						tokens.push_back({T_COMMENT, pos, 2});
						pos += 2;
						in_block_comment = false;
					} else {
						size_t end = pos;
						while (end < line.size()) {
							if (line[end] == L']' && end + 1 < line.size() && line[end + 1] == L']')
								break;
							end++;
						}
						tokens.push_back({T_COMMENT, pos, end - pos});
						pos = end;
					}
					continue;
				}

				// Long string continuation
				if (in_long_string) {
					if (c == L']' && pos + 1 < line.size() && line[pos + 1] == L']') {
						tokens.push_back({T_STRING, pos, 2});
						pos += 2;
						in_long_string = false;
					} else {
						size_t end = pos;
						while (end < line.size()) {
							if (line[end] == L']' && end + 1 < line.size() && line[end + 1] == L']')
								break;
							end++;
						}
						tokens.push_back({T_STRING, pos, end - pos});
						pos = end;
					}
					continue;
				}

				// Whitespace
				if (c == L' ' || c == L'\t') {
					size_t start = pos;
					while (pos < line.size() && (line[pos] == L' ' || line[pos] == L'\t'))
						pos++;
					tokens.push_back({T_WHITESPACE, start, pos - start});
					continue;
				}

				// Comment: -- (single line) or --[[ (block)
				if (c == L'-' && pos + 1 < line.size() && line[pos + 1] == L'-') {
					if (pos + 3 < line.size() && line[pos + 2] == L'[' && line[pos + 3] == L'[') {
						tokens.push_back({T_COMMENT, pos, 4});
						pos += 4;
						in_block_comment = true;
					} else {
						tokens.push_back({T_COMMENT, pos, line.size() - pos});
						pos = line.size();
					}
					continue;
				}

				// Double-quoted string
				if (c == L'"') {
					size_t start = pos;
					pos++;
					while (pos < line.size()) {
						if (line[pos] == L'\\') {
							pos += 2;
						} else if (line[pos] == L'"') {
							pos++;
							break;
						} else {
							pos++;
						}
					}
					tokens.push_back({T_STRING, start, pos - start});
					continue;
				}

				// Single-quoted string
				if (c == L'\'') {
					size_t start = pos;
					pos++;
					while (pos < line.size()) {
						if (line[pos] == L'\\') {
							pos += 2;
						} else if (line[pos] == L'\'') {
							pos++;
							break;
						} else {
							pos++;
						}
					}
					tokens.push_back({T_STRING, start, pos - start});
					continue;
				}

				// Long string [[
				if (c == L'[' && pos + 1 < line.size() && line[pos + 1] == L'[') {
					tokens.push_back({T_STRING, pos, 2});
					pos += 2;
					in_long_string = true;
					continue;
				}

				// Number
				if (std::iswdigit(c) || (c == L'.' && pos + 1 < line.size()
						&& std::iswdigit(line[pos + 1]))) {
					size_t start = pos;
					if (c == L'0' && pos + 1 < line.size() &&
							(line[pos + 1] == L'x' || line[pos + 1] == L'X')) {
						pos += 2;
						while (pos < line.size() && std::iswxdigit(line[pos]))
							pos++;
					} else {
						while (pos < line.size() && std::iswdigit(line[pos]))
							pos++;
						if (pos < line.size() && line[pos] == L'.') {
							pos++;
							while (pos < line.size() && std::iswdigit(line[pos]))
								pos++;
						}
						if (pos < line.size() && (line[pos] == L'e' || line[pos] == L'E')) {
							pos++;
							if (pos < line.size() && (line[pos] == L'+' || line[pos] == L'-'))
								pos++;
							while (pos < line.size() && std::iswdigit(line[pos]))
								pos++;
						}
					}
					tokens.push_back({T_NUMBER, start, pos - start});
					continue;
				}

				// Identifier or keyword
				if (std::iswalpha(c) || c == L'_') {
					size_t start = pos;
					while (pos < line.size()
							&& (std::iswalnum(line[pos]) || line[pos] == L'_'))
						pos++;
					std::wstring word;
					for (size_t j = start; j < pos; j++)
						word.push_back(line[j]);
					tokens.push_back({classifyWord(word), start, pos - start});
					continue;
				}

				// Multi-char operators
				if ((c == L'.' && pos + 1 < line.size() && line[pos + 1] == L'.') ||
					(c == L'=' && pos + 1 < line.size() && line[pos + 1] == L'=') ||
					(c == L'~' && pos + 1 < line.size() && line[pos + 1] == L'=') ||
					(c == L'<' && pos + 1 < line.size() && line[pos + 1] == L'=') ||
					(c == L'>' && pos + 1 < line.size() && line[pos + 1] == L'=')) {
					tokens.push_back({T_OPERATOR, pos, 2});
					pos += 2;
					continue;
				}

				// Single-char operators
				if (std::wcschr(L"+-*/%^#=<>,:;", c)) {
					tokens.push_back({T_OPERATOR, pos, 1});
					pos++;
					continue;
				}

				// Punctuation
				if (std::wcschr(L"()[]{}", c)) {
					tokens.push_back({T_PUNCTUATION, pos, 1});
					pos++;
					continue;
				}

				// Dot is punctuation
				if (c == L'.') {
					tokens.push_back({T_PUNCTUATION, pos, 1});
					pos++;
					continue;
				}

				pos++;
			}

			m_line_tokens.push_back(tokens);
			line_start = i + 1;
		}
	}

	m_tokenized_text_size = (u32)Text.size();
}

bool GUIEditBoxWithSyntaxHighlight::OnEvent(const SEvent &event)
{
	if (!isEnabled())
		return gui::CGUIEditBox::OnEvent(event);

	if (event.EventType == EET_KEY_INPUT_EVENT && event.KeyInput.PressedDown &&
			event.KeyInput.Control && event.KeyInput.Key == KEY_TAB) {
		return gui::CGUIEditBox::OnEvent(event);
	}

	if (event.EventType == EET_KEY_INPUT_EVENT && event.KeyInput.PressedDown &&
			!event.KeyInput.Control && !event.KeyInput.Shift) {
		switch (event.KeyInput.Key) {
		case KEY_TAB: {
			if (!IsWritable)
				return true;
			inputChar(L'\t');
			calculateScrollPos();
			return true;
		}

		case KEY_RETURN: {
			if (!MultiLine || !IsWritable)
				break;

			s32 line_start = 0;
			for (s32 j = CursorPos - 1; j >= 0; j--) {
				if (Text[j] == L'\n') {
					line_start = j + 1;
					break;
				}
			}

			core::stringw indent;
			for (s32 j = line_start; j < (s32)Text.size(); j++) {
				wchar_t lc = Text[j];
				if (lc == L' ' || lc == L'\t')
					indent += lc;
				else
					break;
			}

			core::stringw to_insert;
			to_insert += L'\n';
			for (size_t j = 0; j < indent.size(); j++)
				to_insert += indent[j];

			inputString(to_insert);
			calculateScrollPos();
			return true;
		}

		default:
			break;
		}
	}

	return gui::CGUIEditBox::OnEvent(event);
}

// Replace tab chars with spaces for display (fonts render \t as placeholder glyphs)
static core::stringw deTab(const core::stringw &s)
{
	core::stringw out;
	for (u32 i = 0; i < s.size(); i++) {
		if (s[i] == L'\t')
			out += L' ';
		else
			out += s[i];
	}
	return out;
}

void GUIEditBoxWithSyntaxHighlight::calculateScrollPos()
{
	if (!AutoScroll)
		return;

	IGUIFont *font = getActiveFont();
	if (!font)
		return;

	s32 cursLine = getLineFromPos(CursorPos);
	if (cursLine < 0)
		return;
	setTextRect(cursLine);
	const bool hasBrokenText = MultiLine || WordWrap;

	// Horizontal scrolling (tab-aware measurements)
	{
		u32 cursorWidth = font->getDimension(CursorChar.c_str()).Width;
		core::stringw *txtLine = hasBrokenText ? &BrokenText[cursLine] : &Text;
		core::stringw display = deTab(*txtLine);
		s32 cPos = hasBrokenText ? CursorPos - BrokenTextPositions[cursLine] : CursorPos;
		s32 cStart = font->getDimension(display.subString(0, (u32)cPos).c_str()).Width;
		s32 cEnd = cStart + cursorWidth;
		s32 txtWidth = font->getDimension(display.c_str()).Width;

		if (txtWidth < FrameRect.getWidth()) {
			HScrollPos = 0;
			setTextRect(cursLine);
		}

		if (CurrentTextRect.UpperLeftCorner.X + cStart < FrameRect.UpperLeftCorner.X) {
			HScrollPos -= FrameRect.UpperLeftCorner.X - (CurrentTextRect.UpperLeftCorner.X + cStart);
			setTextRect(cursLine);
		} else if (CurrentTextRect.UpperLeftCorner.X + cEnd > FrameRect.LowerRightCorner.X) {
			HScrollPos += (CurrentTextRect.UpperLeftCorner.X + cEnd) - FrameRect.LowerRightCorner.X;
			setTextRect(cursLine);
		}
	}

	// Vertical scrolling
	if (hasBrokenText) {
		u32 lineHeight = font->getDimension(L"A").Height + font->getKerning(L'A').Y;
		if (lineHeight >= (u32)FrameRect.getHeight()) {
			VScrollPos = 0;
			setTextRect(cursLine);
			s32 unscrolledPos = CurrentTextRect.UpperLeftCorner.Y;
			s32 pivot = FrameRect.UpperLeftCorner.Y;
			switch (VAlign) {
			case gui::EGUIA_CENTER:
				pivot += FrameRect.getHeight() / 2;
				unscrolledPos += (s32)lineHeight / 2;
				break;
			case gui::EGUIA_LOWERRIGHT:
				pivot += FrameRect.getHeight();
				unscrolledPos += (s32)lineHeight;
				break;
			default:
				break;
			}
			VScrollPos = unscrolledPos - pivot;
			setTextRect(cursLine);
		} else {
			setTextRect(0);
			if (CurrentTextRect.UpperLeftCorner.Y > FrameRect.UpperLeftCorner.Y
					&& VAlign != gui::EGUIA_LOWERRIGHT) {
				VScrollPos = 0;
			} else if (VAlign != gui::EGUIA_UPPERLEFT) {
				u32 lastLine = BrokenTextPositions.empty() ? 0 : (u32)BrokenTextPositions.size() - 1;
				setTextRect((s32)lastLine);
				if (CurrentTextRect.LowerRightCorner.Y < FrameRect.LowerRightCorner.Y) {
					VScrollPos -= FrameRect.LowerRightCorner.Y - CurrentTextRect.LowerRightCorner.Y;
				}
			}

			setTextRect(cursLine);
			if (CurrentTextRect.UpperLeftCorner.Y < FrameRect.UpperLeftCorner.Y) {
				VScrollPos -= FrameRect.UpperLeftCorner.Y - CurrentTextRect.UpperLeftCorner.Y;
				setTextRect(cursLine);
			} else if (CurrentTextRect.LowerRightCorner.Y > FrameRect.LowerRightCorner.Y) {
				VScrollPos += CurrentTextRect.LowerRightCorner.Y - FrameRect.LowerRightCorner.Y;
				setTextRect(cursLine);
			}
		}
	}

	if (VScrollBar)
		VScrollBar->setPos(VScrollPos);
}

void GUIEditBoxWithSyntaxHighlight::draw()
{
	if (!IsVisible)
		return;

	const bool focus = Environment->hasFocus(this);
	IGUISkin *skin = Environment->getSkin();
	if (!skin)
		return;

	// Set background color (same as GUIEditBoxWithScrollBar::draw)
	if (m_bg_color_used) {
		OverrideBgColor = m_bg_color;
	} else if (IsWritable) {
		OverrideBgColor = skin->getColor(EGDC_WINDOW);
	} else {
		OverrideBgColor = 0x00000001;
	}

	video::SColor bgColor = OverrideBgColor;
	if (OverrideBgColor.color == 0) {
		EGUI_DEFAULT_COLOR bgCol = EGDC_GRAY_EDITABLE;
		if (isEnabled())
			bgCol = focus ? EGDC_FOCUSED_EDITABLE : EGDC_EDITABLE;
		bgColor = skin->getColor(bgCol);
	}

	if (!Border && Background)
		skin->draw2DRectangle(this, bgColor, AbsoluteRect, &AbsoluteClippingRect);
	if (Border && IsWritable)
		skin->draw3DSunkenPane(this, bgColor, false, Background,
				AbsoluteRect, &AbsoluteClippingRect);

	calculateFrameRect();

	core::rect<s32> localClipRect = FrameRect;
	localClipRect.clipAgainst(AbsoluteClippingRect);

	IGUIFont *font = getActiveFont();
	if (!font)
		return;

	if (LastBreakFont != font)
		breakText();

	const bool ml = (!PasswordBox && (WordWrap || MultiLine));

	// Re-tokenize if text changed (covers inputChar/inputString/delete paths)
	if (m_tokenized_text_size != (u32)Text.size()
			|| (ml && m_line_tokens.size() != (size_t)BrokenText.size()))
		tokenizeAll();

	const s32 realmbgn = MarkBegin < MarkEnd ? MarkBegin : MarkEnd;
	const s32 realmend = MarkBegin < MarkEnd ? MarkEnd : MarkBegin;
	const s32 hlineStart = ml ? getLineFromPos(realmbgn) : 0;
	const s32 hlineCount = ml ? getLineFromPos(realmend) - hlineStart + 1 : 1;
	const s32 lineCount = ml ? (s32)BrokenText.size() : 1;

	const bool prevOver = OverrideColorEnabled;
	const video::SColor prevColor = OverrideColor;

	if (Text.size()) {
		if (!isEnabled() && !OverrideColorEnabled) {
			OverrideColorEnabled = true;
			OverrideColor = skin->getColor(EGDC_GRAY_TEXT);
		}

		for (s32 i = 0; i < lineCount; ++i) {
			setTextRect(i);

			core::rect<s32> c = localClipRect;
			c.clipAgainst(CurrentTextRect);
			if (!c.isValid())
				continue;

			// Draw each token in its syntax color
			s32 x_offset = CurrentTextRect.UpperLeftCorner.X;

			if ((size_t)i < m_line_tokens.size()) {
				const auto &tokens = m_line_tokens[i];
				const core::stringw &lineText = ml ? BrokenText[i] : Text;

				for (const auto &token : tokens) {
					if (token.type == T_WHITESPACE) {
						core::stringw ws;
						for (size_t k = 0; k < token.length; k++)
							ws += L' ';
						core::dimension2du dim = font->getDimension(ws.c_str());
						x_offset += dim.Width;
						continue;
					}

					core::stringw token_text =
						lineText.subString((u32)token.start, (u32)token.length);

					core::dimension2du dim = font->getDimension(token_text.c_str());
					s32 token_width = dim.Width;
					s32 y = CurrentTextRect.UpperLeftCorner.Y;
					core::rect<s32> token_rect(x_offset, y,
							x_offset + token_width,
							CurrentTextRect.LowerRightCorner.Y);

					font->draw(token_text.c_str(), token_rect,
							colorForToken(token.type), false, true, &localClipRect);

					x_offset += token_width;
				}
			} else {
				const core::stringw &lineText = ml ? BrokenText[i] : Text;
				core::stringw display = deTab(lineText);
				font->draw(display.c_str(), CurrentTextRect,
						OverrideColorEnabled ? OverrideColor :
							skin->getColor(EGDC_BUTTON_TEXT),
						false, true, &localClipRect);
			}

			// Selection highlight for this line
			if (focus && MarkBegin != MarkEnd &&
					i >= hlineStart && i < hlineStart + hlineCount) {
				s32 mbegin = 0, mend = 0;
				s32 lineStartPos = 0;
				s32 lineEndPos;
				const core::stringw &lineText = ml ? BrokenText[i] : Text;

				if (i == hlineStart) {
					core::stringw s =
						lineText.subString(0, (u32)(realmbgn - BrokenTextPositions[i]));
					mbegin = font->getDimension(s.c_str()).Width;
					mbegin += font->getKerning(
							lineText[realmbgn - BrokenTextPositions[i]],
							realmbgn - BrokenTextPositions[i] > 0 ?
								lineText[realmbgn - BrokenTextPositions[i] - 1] : 0).X;
					lineStartPos = realmbgn - BrokenTextPositions[i];
				}
				if (i == hlineStart + hlineCount - 1) {
					core::stringw s2 =
						lineText.subString(0, (u32)(realmend - BrokenTextPositions[i]));
					mend = font->getDimension(s2.c_str()).Width;
					lineEndPos = (s32)s2.size();
				} else {
					mend = font->getDimension(lineText.c_str()).Width;
					lineEndPos = (s32)lineText.size();
				}

				core::rect<s32> sel_rect = CurrentTextRect;
				sel_rect.UpperLeftCorner.X += mbegin;
				sel_rect.LowerRightCorner.X = sel_rect.UpperLeftCorner.X + mend - mbegin;

				skin->draw2DRectangle(this, skin->getColor(EGDC_HIGH_LIGHT),
						sel_rect, &localClipRect);

			core::stringw sel_text =
				deTab(lineText.subString((u32)lineStartPos, (u32)(lineEndPos - lineStartPos)));
			if (sel_text.size()) {
				font->draw(sel_text.c_str(), sel_rect,
						skin->getColor(EGDC_HIGH_LIGHT_TEXT),
						false, true, &localClipRect);
			}
			}
		}

		OverrideColorEnabled = prevOver;
		OverrideColor = prevColor;
	}

	// Draw cursor
	if (isEnabled() && IsWritable) {
		s32 cursorLine = 0;
		core::stringw txtLine;
		s32 startPos = 0;

		if (WordWrap || MultiLine) {
			cursorLine = getLineFromPos(CursorPos);
			if (cursorLine >= 0 && cursorLine < (s32)BrokenText.size()) {
				txtLine = BrokenText[cursorLine];
				startPos = BrokenTextPositions[cursorLine];
			}
		} else {
			txtLine = Text;
			startPos = 0;
		}

		core::stringw s =
			deTab(txtLine.subString(0, (u32)(CursorPos - startPos)));

		s32 charcursorpos = font->getDimension(s.c_str()).Width;

		u32 now = get_time_ms();
		if (focus && (CursorBlinkTime == 0 ||
				(now - BlinkStartTime) % (2 * CursorBlinkTime) < CursorBlinkTime)) {
			setTextRect(cursorLine);
			CurrentTextRect.UpperLeftCorner.X += charcursorpos;

			if (OverwriteMode) {
				core::stringw character = Text.subString((u32)CursorPos, 1);
				s32 mend = font->getDimension(character.c_str()).Width;
				if (mend <= 0)
					mend = font->getDimension(CursorChar.c_str()).Width;
				CurrentTextRect.LowerRightCorner.X = CurrentTextRect.UpperLeftCorner.X + mend;
				skin->draw2DRectangle(this, skin->getColor(EGDC_HIGH_LIGHT),
						CurrentTextRect, &localClipRect);
				font->draw(character.c_str(), CurrentTextRect,
						skin->getColor(EGDC_HIGH_LIGHT_TEXT),
						false, true, &localClipRect);
			} else {
				font->draw(CursorChar, CurrentTextRect,
						OverrideColorEnabled ? OverrideColor :
							skin->getColor(EGDC_BUTTON_TEXT),
						false, true, &localClipRect);
			}
		}
	}

	gui::IGUIElement::draw();
}

// ---- Friend function: parseCodeEdit formspec element ----

static bool check_pos_coords(const std::string &name,
		const std::vector<std::string> &v_pos, size_t idx)
{
	if (stof(v_pos[idx]) < 0) {
		warningstream << "invalid " << name
			<< " element: position coordinates < 0" << std::endl;
		return false;
	}
	return true;
}

static bool check_geom_size(const std::string &name,
		const std::vector<std::string> &v_geom, size_t idx)
{
	if (stof(v_geom[idx]) <= 0) {
		warningstream << "invalid " << name
			<< " element: geometry width/height <= 0" << std::endl;
		return false;
	}
	return true;
}

void parseCodeEdit(GUIFormSpecMenu *menu, GUIFormSpecMenu::parserData *data,
		const std::string &element)
{
	std::vector<std::string> parts;
	if (!menu->precheckElement("codeedit", element, 5, 6, parts))
		return;

	std::vector<std::string> v_pos = split(parts[0], ',');
	std::vector<std::string> v_geom = split(parts[1], ',');
	std::string name = parts[2];
	std::string label = parts[3];
	std::string default_val = parts[4];
	bool readonly = false;
	SyntaxHighlightColors colors;

	if (parts.size() >= 6) {
		std::vector<std::string> opts = split(parts[5], ',');
		for (auto &opt : opts) {
			size_t eq = opt.find('=');
			if (eq == std::string::npos)
				continue;
			std::string key = trim(opt.substr(0, eq));
			std::string val = trim(opt.substr(eq + 1));
			if (key == "readonly" && is_yes(val))
				readonly = true;
		}
		colors = SyntaxHighlightColors::fromOptionString(parts[5]);
	}

	check_pos_coords("codeedit", v_pos, 0);
	check_pos_coords("codeedit", v_pos, 1);
	check_geom_size("codeedit", v_geom, 0);
	check_geom_size("codeedit", v_geom, 1);

	v2s32 pos;
	v2s32 geom;

	if (data->real_coordinates) {
		pos = menu->getRealCoordinateBasePos(v_pos);
		geom = menu->getRealCoordinateGeometry(v_geom);
	} else {
		pos = menu->getElementBasePos(&v_pos);
		pos -= menu->padding;

		geom.X = (s32)(stof(v_geom[0]) * menu->spacing.X) - (s32)(menu->spacing.X - menu->imgsize.X);
		geom.Y = (s32)(stof(v_geom[1]) * (float)menu->imgsize.Y) - (s32)(menu->spacing.Y - menu->imgsize.Y);
		pos.Y += menu->m_btn_height;
	}

	core::rect<s32> rect = core::rect<s32>(pos.X, pos.Y,
			pos.X + geom.X, pos.Y + geom.Y);

	if (!data->explicit_size)
		warningstream << "invalid use of positioned codeedit without a size[] element" << std::endl;

	if (menu->m_form_src)
		default_val = menu->m_form_src->resolveText(default_val);

	std::wstring wlabel = translate_string(utf8_to_wide(unescape_string(label)));

	GUIFormSpecMenu::FieldSpec spec(
		name,
		wlabel,
		utf8_to_wide(unescape_string(default_val)),
		258 + (s32)menu->m_fields.size(),
		0,
		gui::ECI_IBEAM
	);

	bool is_editable = !spec.fname.empty() && !readonly;

	if (!is_editable) {
		auto style = menu->getDefaultStyleForElement("codeedit");
		menu->addLabel(EnrichedString(spec.flabel.c_str()),
				rect, data->current_parent, style);
		return;
	}

	spec.send = true;

	auto *e = new GUIEditBoxWithSyntaxHighlight(
		spec.fdefault.c_str(), true,
		menu->Environment,
		data->current_parent,
		spec.fid,
		rect,
		menu->m_tsrc,
		!readonly,
		colors
	);

	auto style = menu->getDefaultStyleForElement("codeedit", spec.fname);

	if (e) {
		if (spec.fname == menu->m_focused_element)
			menu->Environment->setFocus(e);

		e->setMultiLine(true);
		e->setWordWrap(false);
		e->setTextAlignment(gui::EGUIA_UPPERLEFT, gui::EGUIA_UPPERLEFT);
		e->setNotClipped(style.getBool(StyleSpec::NOCLIP, false));
		e->setOverrideColor(style.getColor(StyleSpec::TEXTCOLOR,
				video::SColor(0xFFFFFFFF)));
		bool border = style.getBool(StyleSpec::BORDER, true);
		e->setDrawBorder(border);
		e->setDrawBackground(border);
		e->setOverrideFont(style.getFont());
		if (style.hasProperty(StyleSpec::BGCOLOR))
			e->setBackgroundColor(style.getColor(StyleSpec::BGCOLOR));
		e->drop();
	}

	if (!spec.flabel.empty()) {
		int font_height = g_fontengine->getTextHeight();
		rect.UpperLeftCorner.Y -= font_height;
		rect.LowerRightCorner.Y = rect.UpperLeftCorner.Y + font_height;
		menu->addLabel(EnrichedString(spec.flabel.c_str()),
				rect, data->current_parent, style);
	}

	menu->m_fields.push_back(spec);
}

// ---- Static self-registration ----

namespace {
	const bool registered = GUIFormSpecMenu::registerElementParser(
		"codeedit", parseCodeEdit
	);
}
